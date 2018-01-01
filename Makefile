default: build

SRC = $(shell find src -name "*.ls" -type f | sort)
LIB = $(SRC:src/%.ls=lib/%.js)

node_modules:
	npm install

lib:
	mkdir lib/

lib/%.js: src/%.ls lib node_modules
	node node_modules/livescript/bin/lsc --output "$(@D)" --compile "$<"

build: $(LIB)

clean:
	rm -rf lib/

