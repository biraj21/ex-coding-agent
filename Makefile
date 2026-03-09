
BIN := excode

.PHONY: build run clean

build:
	mix escript.build

run:
	mix run -e 'ExCode.main(System.argv())'

clean:
	rm -rf $(BIN)