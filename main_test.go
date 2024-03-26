package main

import (
	"os"
	"testing"

	dns "github.com/cert-manager/cert-manager/test/acme"
)

func TestRunsSuite(t *testing.T) {
	var zone string
	var manifest string
	var dnsServer string
	var found bool

	if zone, found = os.LookupEnv("TEST_ZONE_NAME"); found == false {
		zone = "aldune.private"
	}

	if dnsServer, found = os.LookupEnv("TEST_DNS_SERVER"); found == false {
		dnsServer = "10.0.0.5:53"
	}

	if manifest, found = os.LookupEnv("TEST_MANIFEST_PATH"); found == false {
		manifest = "testdata/my-custom-solver"
	}

	// The manifest path should contain a file named config.json that is a
	// snippet of valid configuration that should be included on the
	// ChallengeRequest passed as part of the test cases.

	fixture := dns.NewFixture(&designateDNSProviderSolver{},
		dns.SetResolvedZone(zone),
		dns.SetDNSName(zone),
		dns.SetDNSServer(dnsServer),
		dns.SetAllowAmbientCredentials(false),
		dns.SetManifestPath(manifest),
	)

	fixture.RunBasic(t)
	fixture.RunExtended(t)
}
