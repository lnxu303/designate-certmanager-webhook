package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"

	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/dns/v2/recordsets"
	"github.com/gophercloud/gophercloud/openstack/dns/v2/zones"
	"github.com/gophercloud/gophercloud/pagination"
	"github.com/gophercloud/utils/openstack/clientconfig"

	extapi "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	"k8s.io/client-go/rest"
	log "k8s.io/klog/v2"

	"github.com/cert-manager/cert-manager/pkg/acme/webhook"
	"github.com/cert-manager/cert-manager/pkg/acme/webhook/apis/acme/v1alpha1"
	"github.com/cert-manager/cert-manager/pkg/acme/webhook/cmd"
)

var phVersion = "v0.0.0-unset"
var phBuildDate = ""

func main() {
	groupName := os.Getenv("GROUP_NAME")

	if groupName == "" {
		panic("GROUP_NAME must be specified")
	}

	cmd.RunWebhookServer(groupName,
		&designateDNSProviderSolver{},
	)
}

type designateDNSProviderConfig struct {
	Cloud  string `json:"cloud,omitempty"`
	TTL    int    `json:"ttl,omitempty",default:3600`
	Verify bool   `json:"verify,omitempty",default:true`
}

type designateDNSProviderSolver struct {
	client *gophercloud.ServiceClient
	config *designateDNSProviderConfig
}

func New() webhook.Solver {
	return &designateDNSProviderSolver{}
}

func createDesignateServiceClient(cloud string, insecure bool) (client *gophercloud.ServiceClient, err error) {
	if client, err = clientconfig.NewServiceClient("dns", &clientconfig.ClientOpts{Cloud: cloud}); err == nil {
		// Ignore secure tls
		if transport, ok := client.HTTPClient.Transport.(*http.Transport); ok {
			if transport.TLSClientConfig != nil {
				transport.TLSClientConfig.InsecureSkipVerify = insecure
			}
		}
	}

	return
}

func (c *designateDNSProviderSolver) loadConfig(cfgJSON *extapi.JSON) (err error) {
	if c.config == nil {
		c.config = &designateDNSProviderConfig{
			TTL:    600,
			Verify: true,
		}

		if cfgJSON != nil {
			if err = json.Unmarshal(cfgJSON.Raw, &c.config); err != nil {
				log.Errorf("Can't decode config: %v", err)

				err = fmt.Errorf("error decoding solver config: %v", err)
			}
		} else {
			log.Warningln("Config is not defined")
		}
	}

	if c.client == nil && err == nil {
		c.client, err = createDesignateServiceClient(c.config.Cloud, !c.config.Verify)
	}

	return
}

func (c *designateDNSProviderSolver) Name() string {
	return "designate-dns"
}

func (c *designateDNSProviderSolver) Present(ch *v1alpha1.ChallengeRequest) (err error) {
	log.V(4).Infof("Present() called ch.DNSName=%s ch.ResolvedZone=%s ch.ResolvedFQDN=%s ch.Type=%s", ch.DNSName, ch.ResolvedZone, ch.ResolvedFQDN, ch.Type)

	var allPages pagination.Page
	var allZones []zones.Zone

	if err = c.loadConfig(ch.Config); err != nil {
		return fmt.Errorf("unable to load config. Reason: %v", err)
	}

	if allPages, err = zones.List(c.client, zones.ListOpts{Name: ch.ResolvedZone}).AllPages(); err != nil {
		return fmt.Errorf("unable to list zone: %s. Reason: %v", ch.ResolvedZone, err)
	}

	if allZones, err = zones.ExtractZones(allPages); err != nil {
		return fmt.Errorf("unable to extract zone: %s. Reason: %v", ch.ResolvedZone, err)
	}

	if len(allZones) != 1 {
		return fmt.Errorf("Present: Expected to find 1 zone %s, found %v", ch.ResolvedZone, len(allZones))
	}

	opts := recordsets.CreateOpts{
		Name: ch.ResolvedFQDN,
		Type: "TXT",
		TTL:  c.config.TTL,
		Records: []string{
			ch.Key,
		},
	}

	if _, err = recordsets.Create(c.client, allZones[0].ID, opts).Extract(); err != nil {
		return fmt.Errorf("unable to create recordset: %s in zone: %s. Reason: %v", ch.ResolvedFQDN, ch.ResolvedZone, err)
	}

	return
}

func (c *designateDNSProviderSolver) CleanUp(ch *v1alpha1.ChallengeRequest) (err error) {
	log.V(4).Infof("CleanUp called ch.ResolvedZone=%s ch.ResolvedFQDN=%s", ch.ResolvedZone, ch.ResolvedFQDN)

	var allPages pagination.Page
	var allZones []zones.Zone
	var allRRs []recordsets.RecordSet

	if err = c.loadConfig(ch.Config); err != nil {
		return fmt.Errorf("unable to load config. Reason: %v", err)
	}

	if allPages, err = zones.List(c.client, zones.ListOpts{Name: ch.ResolvedZone}).AllPages(); err != nil {
		return fmt.Errorf("unable to list zone: %s. Reason: %v", ch.ResolvedZone, err)
	}

	if allZones, err = zones.ExtractZones(allPages); err != nil {
		return fmt.Errorf("unable to extract zone: %s. Reason: %v", ch.ResolvedZone, err)
	}

	if len(allZones) != 1 {
		return fmt.Errorf("CleanUp: Expected to find 1 zone %s, found %v", ch.ResolvedZone, len(allZones))
	}

	recordListOpts := recordsets.ListOpts{
		Name: ch.ResolvedFQDN,
		Type: "TXT",
		Data: ch.Key,
	}

	if allPages, err = recordsets.ListByZone(c.client, allZones[0].ID, recordListOpts).AllPages(); err != nil {
		return fmt.Errorf("unable to list recordsets in zone: %s. Reason: %v", ch.ResolvedZone, err)
	}

	if allRRs, err = recordsets.ExtractRecordSets(allPages); err != nil {
		return fmt.Errorf("unable to extract recordsets in zone: %s. Reason: %v", ch.ResolvedZone, err)
	}

	if len(allRRs) != 1 {
		return fmt.Errorf("CleanUp: Expected to find 1 recordset matching %s in zone %s, found %v", ch.ResolvedFQDN, ch.ResolvedZone, len(allRRs))
	}

	// TODO rather than deleting the whole recordset we may have to delete individual records from it, i.e. perform an update rather than a delete
	if err = recordsets.Delete(c.client, allZones[0].ID, allRRs[0].ID).ExtractErr(); err != nil {
		return fmt.Errorf("unable to delete recordset: %s in zone: %s. Reason: %v", allRRs[0].ID, ch.ResolvedZone, err)
	}

	return
}

func (c *designateDNSProviderSolver) Initialize(kubeClientConfig *rest.Config, stopCh <-chan struct{}) (err error) {
	log.Infof("designate-certmanager-webhook initialize. version: %s, build date: %s", phVersion, phBuildDate)

	return
}
