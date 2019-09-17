COMPONENTS=src/main/components
SOURCE=src/main/source

$(SOURCE)/LaunchDarkly.brs: $(shell find rawsrc/ -type f)
	cat $(shell find rawsrc/ -type f) > $@

build: $(SOURCE)/LaunchDarkly.brs

package: build $(SOURCE)/main.brs $(COMPONENTS)/LaunchDarklyTask.brs $(COMPONENTS)/LaunchDarklyTask.xml
	rm -rf package package.zip && mkdir -p package
	cp $(SOURCE)/LaunchDarkly.brs package/
	cp $(COMPONENTS)/LaunchDarkly* package/
	zip -r package.zip package

install: build
	ukor install main roku

test: build
	ukor test main roku

console:
	ukor console roku

lint:
	ukor lint main
