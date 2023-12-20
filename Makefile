# Makefile for RocksDB benchmark tool

# Define the target executable
TARGET = rocks_cli
SOURCE = rockscli.cpp
LIBVERSION = 6.8.1

# Define the compiler and the flags
CXX = g++
CXXFLAGS = -I./rocksdb-6.8.1/include -L./rocksdb-6.8.1 -lrocksdb -lpthread -lsnappy -ldl

ROCKSDB_DATA = ./rocksdbdata
# Default rule
all:  $(TARGET)

# Rule to compile the program
$(TARGET): $(SOURCE)
	$(CXX) -o $(TARGET) $(SOURCE) $(CXXFLAGS)

# Clean rule:
clean:
	rm -rf $(TARGET) $(ROCKSDB_DATA) rocks_* *enclave

# Rule to run the program
run-native: $(TARGET)
	rm -rf $(ROCKSDB_DATA)
	mkdir $(ROCKSDB_DATA)
	LD_LIBRARY_PATH=./rocksdb-6.8.1 ./$(TARGET) $(ROCKSDB_DATA) 15000 1 50
gen-man:
	./gen_man.sh -s ./generic.manifest.template ./rocks_cli error

run-direct:
	rm -rf $(ROCKSDB_DATA)
	mkdir $(ROCKSDB_DATA)
	gramine-direct ./$(TARGET) $(CURDIR)/$(ROCKSDB_DATA) 15000 1 50
