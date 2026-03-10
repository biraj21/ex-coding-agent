
BIN := excode

.PHONY: build run clean

type-check:
	mix dialyzer

build: type-check
	mix escript.build

run:
	mix run -e 'ExCode.main(System.argv())'

clean:
	rm -rf $(BIN)
