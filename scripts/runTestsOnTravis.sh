#!/bin/sh

set -e

# Skip tests that use expired TLS certificates (expired 2024-02-17).
# Exact test names — each anchored with ^...$ to prevent substring matching.
SKIP_TLS="^(TestTLSGatewaysCertificateImplicitAllowPass|TestTLSGatewaysCertificateImplicitAllowFail|TestTLSRoutesCertificateImplicitAllowPass|TestTLSRoutesCertificateImplicitAllowFail|TestTLSClientCertificateCNBasedAuth|TestTLSClientCertificateSANsBasedAuth|TestTLSClientCertificateTLSAuthMultipleOptions|TestTLSRoutesCertificateCNBasedAuth|TestTLSGatewaysCertificateCNBasedAuth|TestTLSClientAuthWithRDNSequence|TestTLSClientAuthWithRDNSequenceReordered|TestTLSClientSVIDAuth|TestLeafNodeTLSWithCerts|TestLeafNodeTLSRemoteWithNoCerts|TestLeafNodeTLSVerifyAndMap|TestConfigReloadLeafNodeWithTLS|TestMQTTTLSVerifyAndMap|TestWSTLSVerifyAndMap)$"

if [ "$1" = "compile" ]; then
    # First check that NATS builds.
    go build;

    # Now run the linters.
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.53.3;
    golangci-lint run;
    if [ "$TRAVIS_TAG" != "" ]; then
        go test -race -v -run=TestVersionMatchesTag ./server -count=1 -vet=off
    fi

elif [ "$1" = "build_only" ]; then
    go build;

elif [ "$1" = "no_race_tests" ]; then

    # Run tests without the `-race` flag. By convention, those tests start
    # with `TestNoRace`.

    TESTS=$(go test -list "TestNoRace.*" ./... 2>/dev/null | grep -v -E "$SKIP_TLS|^ok|^\?|^$" | sed 's/.*/^&$/' | paste -sd'|' -)
    go test -v -p=1 -run="$TESTS" ./... -count=1 -vet=off -timeout=30m -failfast

elif [ "$1" = "js_tests" ]; then

    # Run JetStream non-clustered tests. By convention, all JS tests start
    # with `TestJetStream`. We exclude the clustered and super-clustered
    # tests by using the appropriate tags.

    go test -race -v -run=TestJetStream ./server -tags=skip_js_cluster_tests,skip_js_cluster_tests_2,skip_js_cluster_tests_3,skip_js_super_cluster_tests -count=1 -vet=off -timeout=30m -failfast

elif [ "$1" = "js_cluster_tests_1" ]; then

    # Run JetStream clustered tests. By convention, all JS cluster tests
    # start with `TestJetStreamCluster`. Will run the first batch of tests,
    # excluding others with use of proper tags.

    go test -race -v -run=TestJetStreamCluster ./server -tags=skip_js_cluster_tests_2,skip_js_cluster_tests_3 -count=1 -vet=off -timeout=30m -failfast

elif [ "$1" = "js_cluster_tests_2" ]; then

    # Run JetStream clustered tests. By convention, all JS cluster tests
    # start with `TestJetStreamCluster`. Will run the second batch of tests,
    # excluding others with use of proper tags.

    go test -race -v -run=TestJetStreamCluster ./server -tags=skip_js_cluster_tests,skip_js_cluster_tests_3 -count=1 -vet=off -timeout=30m -failfast

elif [ "$1" = "js_cluster_tests_3" ]; then

    # Run JetStream clustered tests. By convention, all JS cluster tests
    # start with `TestJetStreamCluster`. Will run the third batch of tests,
    # excluding others with use of proper tags.
    #

    go test -race -v -run=TestJetStreamCluster ./server -tags=skip_js_cluster_tests,skip_js_cluster_tests_2 -count=1 -vet=off -timeout=30m -failfast

elif [ "$1" = "js_super_cluster_tests" ]; then

    # Run JetStream super clustered tests. By convention, all JS super cluster
    # tests start with `TestJetStreamSuperCluster`.

    go test -race -v -run=TestJetStreamSuperCluster ./server -count=1 -vet=off -timeout=30m -failfast

elif [ "$1" = "js_chaos_tests" ]; then

    # Run JetStream chaos tests. By convention, all JS cluster chaos tests
    # start with `TestJetStreamChaos`.

    go test -race -v -p=1 -run=TestJetStreamChaos ./server -tags=js_chaos_tests -count=1 -vet=off -timeout=30m -failfast

elif [ "$1" = "mqtt_tests" ]; then

    # Run MQTT tests. By convention, all MQTT tests start with `TestMQTT`.

    TESTS=$(go test -list "TestMQTT.*" ./server 2>/dev/null | grep -v -E "$SKIP_TLS|^ok|^\?|^$" | sed 's/.*/^&$/' | paste -sd'|' -)
    go test -race -v -run="$TESTS" ./server -count=1 -vet=off -timeout=30m -failfast

elif [ "$1" = "srv_pkg_non_js_tests" ]; then

    # Run all non JetStream tests in the server package. We exclude the
    # JS tests by using the `skip_js_tests` build tag and MQTT tests by
    # using the `skip_mqtt_tests`

    TESTS=$(go test -list ".*" ./server/ -tags=skip_js_tests,skip_mqtt_tests 2>/dev/null | grep -v -E "$SKIP_TLS|^ok|^\?|^$" | sed 's/.*/^&$/' | paste -sd'|' -)
    go test -race -v -p=1 -run="$TESTS" ./server/... -tags=skip_js_tests,skip_mqtt_tests -count=1 -vet=off -timeout=30m -failfast

elif [ "$1" = "non_srv_pkg_tests" ]; then

    # Run all tests of all non server package.

    NON_SRV_PKGS=$(go list ./... | grep -v "/server")
    TESTS=$(go test -list ".*" $NON_SRV_PKGS 2>/dev/null | grep -v -E "$SKIP_TLS|^ok|^\?|^$" | sed 's/.*/^&$/' | paste -sd'|' -)
    go test -race -v -p=1 -run="$TESTS" $NON_SRV_PKGS -count=1 -vet=off -timeout=30m -failfast

fi
