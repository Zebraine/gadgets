.PHONY: all mkdir run build sanitize clean

CXX ?= g++
CXXFLAGS ?= -std=c++23 -Wall -Wextra

all: run

mkdir:
	mkdir -p bin

run:build
	./bin/radix_tree

build:mkdir
	$(CXX) -o bin/radix_tree main.cpp $(CXXFLAGS)

sanitize:mkdir
	$(CXX) -o bin/radix_tree_sanitize main.cpp $(CXXFLAGS) -fsanitize=address,undefined -fno-omit-frame-pointer
	./bin/radix_tree_sanitize

clean:
	rm -f bin/radix_tree bin/radix_tree_sanitize
