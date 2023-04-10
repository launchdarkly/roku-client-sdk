MAIN_COMPONENTS=src/main/components
MAIN_SOURCE=src/main/source

CONTRACT_TESTS_COMPONENTS=src/contract-tests/components
CONTRACT_TESTS_SOURCE=src/contract-tests/source

FLAVOR ?= main

.PHONY: help
help: #! Show this help message
	@echo 'Usage: make [target] ... '
	@echo ''
	@echo 'Targets:'
	@grep -h -F '#!' $(MAKEFILE_LIST) | grep -v grep | sed 's/:.*#!/:/' | column -t -s":"

guard-%:
	@if [ "${${*}}" = "" ]; then \
		echo "Parameter variable $* not set"; \
		exit 1; \
	fi

.PHONY: build-library
build-library:
	@cat $(shell find rawsrc/ -type f) > $(MAIN_SOURCE)/LaunchDarkly.brs
	@cp $(MAIN_SOURCE)/LaunchDarkly.brs $(CONTRACT_TESTS_SOURCE)/LaunchDarkly.brs
	@cp $(MAIN_COMPONENTS)/LaunchDarklyTask.brs $(CONTRACT_TESTS_COMPONENTS)/LaunchDarklyTask.brs
	@cp $(MAIN_COMPONENTS)/LaunchDarklyTask.xml $(CONTRACT_TESTS_COMPONENTS)/LaunchDarklyTask.xml

package: #! Create a package.zip for release
package: build-library $(MAIN_SOURCE)/main.brs $(MAIN_COMPONENTS)/LaunchDarklyTask.brs $(MAIN_COMPONENTS)/LaunchDarklyTask.xml
	@rm -rf package package.zip && mkdir -p package
	@cp $(MAIN_SOURCE)/LaunchDarkly.brs package/
	@cp $(MAIN_COMPONENTS)/LaunchDarkly* package/
	@zip -r package.zip package

install: #! Install a library driver onto the roku device
install: build-library
	@ukor install $(FLAVOR) roku

test: #! Run the unit tests
test: build-library
	@ukor test $(FLAVOR) roku

console: #! View running console logs
console:
	@ukor console roku

lint: #! Perform style checking
lint:
	@ukor lint $(FLAVOR)

.PHONY: run-contract-tests
start-contract-test-service:
	@$(MAKE) install FLAVOR=contract-tests

.PHONY: run-contract-tests
run-contract-tests: guard-HOST_IP guard-ROKU_IP
	curl -s https://raw.githubusercontent.com/launchdarkly/sdk-test-harness/main/downloader/run.sh \
      | VERSION=v1 PARAMS="-host $(HOST_IP) -url http://$(ROKU_IP):9000 -debug -stop-service-at-end -skip-from ./src/contract-tests/testharness-suppressions.txt $(TEST_HARNESS_PARAMS)" sh

.PHONY: contract-tests
contract-tests: #! Run the SDK test harness contract tests
contract-tests: start-contract-test-service run-contract-tests
