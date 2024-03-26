package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/gophercloud/gophercloud"
	"github.com/gophercloud/gophercloud/openstack/dns/v2/recordsets"
	"github.com/gophercloud/gophercloud/openstack/dns/v2/zones"
	"github.com/gophercloud/gophercloud/pagination"
	"github.com/gophercloud/utils/openstack/clientconfig"

	log "github.com/sirupsen/logrus"
	extapi "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	"k8s.io/client-go/rest"

	"github.com/cert-manager/cert-manager/pkg/acme/webhook"
	"github.com/cert-manager/cert-manager/pkg/acme/webhook/apis/acme/v1alpha1"
	"github.com/cert-manager/cert-manager/pkg/acme/webhook/cmd"
)

var phVersion = "v0.0.0-unset"
var phBuildDate = ""
var GroupName = os.Getenv("GROUP_NAME")

func main() {
	if GroupName == "" {
		panic("GROUP_NAME must be specified")
	}

	cmd.RunWebhookServer(GroupName,
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
			log.Warn("Config is not defined")
		}
	}

	if c.client == nil && err == nil {
		c.client, err = c.createDesignateServiceClient()
	}

	return
}

func (c *designateDNSProviderSolver) Name() string {
	return "designateDNS"
}

func (c *designateDNSProviderSolver) Present(ch *v1alpha1.ChallengeRequest) (err error) {
	log.Debugf("Present() called ch.DNSName=%s ch.ResolvedZone=%s ch.ResolvedFQDN=%s ch.Type=%s", ch.DNSName, ch.ResolvedZone, ch.ResolvedFQDN, ch.Type)

	var allPages pagination.Page
	var allZones []zones.Zone

	if err = c.loadConfig(ch.Config); err != nil {
		return
	}

	if allPages, err = zones.List(c.client, zones.ListOpts{Name: ch.ResolvedZone}).AllPages(); err != nil {
		return
	}

	if allZones, err = zones.ExtractZones(allPages); err != nil {
		return
	}

	if len(allZones) != 1 {
		return fmt.Errorf("Present: Expected to find 1 zone %s, found %v", ch.ResolvedZone, len(allZones))
	}

	opts := recordsets.CreateOpts{
		Name: ch.ResolvedFQDN,
		Type: "TXT",
		TTL:  c.config.TTL,
		Records: []string{
			quoteRecord(ch.Key),
		},
	}

	_, err = recordsets.Create(c.client, allZones[0].ID, opts).Extract()

	return
}

func (c *designateDNSProviderSolver) CleanUp(ch *v1alpha1.ChallengeRequest) (err error) {
	log.Debugf("CleanUp called ch.ResolvedZone=%s ch.ResolvedFQDN=%s", ch.ResolvedZone, ch.ResolvedFQDN)

	var allPages pagination.Page
	var allZones []zones.Zone
	var allRRs []recordsets.RecordSet

	if err = c.loadConfig(ch.Config); err != nil {
		return
	}

	if allPages, err = zones.List(c.client, zones.ListOpts{Name: ch.ResolvedZone}).AllPages(); err != nil {
		return
	}

	if allZones, err = zones.ExtractZones(allPages); err != nil {
		return
	}

	if len(allZones) != 1 {
		return fmt.Errorf("CleanUp: Expected to find 1 zone %s, found %v", ch.ResolvedZone, len(allZones))
	}

	recordListOpts := recordsets.ListOpts{
		Name: ch.ResolvedFQDN,
		Type: "TXT",
		Data: quoteRecord(ch.Key),
	}

	if allPages, err = recordsets.ListByZone(c.client, allZones[0].ID, recordListOpts).AllPages(); err != nil {
		return
	}

	if allRRs, err = recordsets.ExtractRecordSets(allPages); err != nil {
		return
	}

	if len(allRRs) != 1 {
		return fmt.Errorf("CleanUp: Expected to find 1 recordset matching %s in zone %s, found %v", ch.ResolvedFQDN, ch.ResolvedZone, len(allRRs))
	}

	// TODO rather than deleting the whole recordset we may have to delete individual records from it, i.e. perform an update rather than a delete
	err = recordsets.Delete(c.client, allZones[0].ID, allRRs[0].ID).ExtractErr()

	return err
}

func (c *designateDNSProviderSolver) createDesignateServiceClient() (client *gophercloud.ServiceClient, err error) {
	if client, err = clientconfig.NewServiceClient("dns", &clientconfig.ClientOpts{Cloud: c.config.Cloud}); err == nil {
		// Ignore secure tls
		if transport, ok := client.HTTPClient.Transport.(*http.Transport); ok {
			if transport.TLSClientConfig != nil {
				transport.TLSClientConfig.InsecureSkipVerify = c.config.Verify
			}
		}
	}

	return
}

func (c *designateDNSProviderSolver) Initialize(kubeClientConfig *rest.Config, stopCh <-chan struct{}) (err error) {
	log.Infof("designate-certmanager-webhook initialize. version: %s, build date: %s", phVersion, phBuildDate)

	return
}

func quoteRecord(r string) string {
	if strings.HasPrefix(r, "\"") && strings.HasSuffix(r, "\"") {
		return r
	} else {
		return strconv.Quote(r)
	}
}
