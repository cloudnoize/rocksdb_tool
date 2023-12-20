#include <rocksdb/db.h>
#include <random>
#include <string>
#include <iostream>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <thread>

std::string generateRandomString(size_t length) {
    std::random_device rd;
    std::mt19937 rng(rd());
    std::uniform_int_distribution<> index_dist(1,255);
    std::string result;
    for (size_t i = 0; i < length; ++i) {
        result += char(index_dist(rng));
    }
    return result;
}

std::string getCurrentTimeWithMillisec() {
    using namespace std::chrono;

    // Capture the current time
    auto now = system_clock::now();
    auto nowAsTimeT = system_clock::to_time_t(now);
    auto nowMs = duration_cast<milliseconds>(now.time_since_epoch()) % 1000;

    // Format the time
    std::stringstream ss;
    ss << std::put_time(std::localtime(&nowAsTimeT), "%Y-%m-%d %H:%M:%S");
    ss << '.' << std::setfill('0') << std::setw(3) << nowMs.count();

    return ss.str();
}

int main(int argc, char* argv[]) {
    if (argc != 5) {
        std::cerr << "Usage: " << argv[0] << " <DB path> <Target DB size in MB> <Sleep duration in ms> <Avg calc interval>" << std::endl;
        return 1;
    }

    std::string dbPath = argv[1];
    size_t targetSizeMB = std::stoul(argv[2]);
    int sleepDurationMS = std::stoi(argv[3]);
    int avgInterval = std::stoi(argv[4]);

    rocksdb::DB* db;
    rocksdb::Options options;
    options.create_if_missing = true;

    // Open the database
    rocksdb::Status status = rocksdb::DB::Open(options, dbPath, &db);
    if (!status.ok()) {
        std::cerr << "Unable to open/create database at '" << dbPath << "',Please delete old data if exists" << std::endl;
        return 1;
    }

    // Create a column family
    rocksdb::ColumnFamilyHandle* cf;
    rocksdb::ColumnFamilyOptions cf_options;
    status = db->CreateColumnFamily(cf_options, "LATEST", &cf);
    if (!status.ok()) {
        std::cerr << "Unable to create column family 'LATEST'" << std::endl;
        return 1;
    }

    size_t dbSize = 0;
    const size_t targetSize = targetSizeMB * 1024 * 1024; // Convert MB to Bytes
    const size_t keySize = 20;
    const size_t valueSize = 20 * 1024; // 20KB
    long long totalTime = 0;
    int putCount = 0;

    while (dbSize < targetSize) {
        std::string key = generateRandomString(keySize);
	std::string key2 = generateRandomString(keySize);
        std::string value = generateRandomString(valueSize);

        auto start = std::chrono::high_resolution_clock::now();
	std::string dbvalue;
	rocksdb::Status s = db->Get(rocksdb::ReadOptions(), key, &dbvalue);
	if (s.ok()) {
		std::cout << "KEy " << key << " found in db" << "\n";
	}
	s = db->Get(rocksdb::ReadOptions(), key2, &dbvalue);
        if (s.ok()) {
                std::cout << "KEy " << key2 << " found in db" << "\n";
        }
        status = db->Put(rocksdb::WriteOptions(), cf, key, value);
        status = db->Put(rocksdb::WriteOptions(), cf, key2, key);
        auto end = std::chrono::high_resolution_clock::now();
        if (!status.ok()) {
            std::cerr << "Failed to write data to RocksDB" << std::endl;
            break;
        }

        totalTime += std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
        putCount++;
        if (putCount % avgInterval == 0) {
            std::cout <<  getCurrentTimeWithMillisec() << " Multi average duration for " << avgInterval << " puts: "
                      << (totalTime / avgInterval) << " microseconds, estimated db size "
                      << dbSize << "Bytes" << std::endl;
            totalTime = 0;
        }

        dbSize += keySize + valueSize;
        std::this_thread::sleep_for(std::chrono::milliseconds(sleepDurationMS));
    }

    std::cout << "Approximately " << targetSizeMB << "MB of data written to the 'LATEST' column family." << std::endl;

    // Close the database
    db->DestroyColumnFamilyHandle(cf);
    delete db;

    return 0;
}

