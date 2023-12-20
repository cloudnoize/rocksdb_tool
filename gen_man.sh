#!/usr/bin/env bash
# Contact - mmanikda

Usage() {
	echo "Help:
		"Try to be as absolute as possible with paths"
		"Relative paths are considered to be starting at place from where you will be running gramine manifest creation script"
		"Always run this script from directory where you will run gramine"
		"For example - We run apollo tests from /concord-bft/tests/apollo directory in container"

		Arguments supported are (used one at a time) :
		-s | --single :  create manifest for single executable
		-r | --recursive : create manifests for all executables found in given dir path recursively
		-c | --cleanup : remove manifests, sgx, sig files recursively for all executables in a given dir path
		
		Usage:
		./generate_manifest_files.sh -s <generic template file absolute full path> <executable absolute full path> <gramine_log_level> {error|debug|trace}
		./generate_manifest_files.sh -r <generic template file absolute full path> <directory absolute full path> <gramine_log_level> {error|debug|trace}
		./generate_manifest_files.sh -c <directory path>
		"
	exit 1
}


CheckIfFileExists() {
	file_path=$1
	if [ ! -f ${file_path} ]; then
		echo "file ${file_path} not found"
		exit 1
	fi
}


CheckIfDirExists() {
	dir_path=$1
	if [ ! -d ${dir_path} ]; then
		echo "directory ${dir_path} not found"
		exit 1
	fi
}


CreateManifestForSingleExecutable() {
	manifest_template_fname=$1
	executable_path=$2
	log_level=$3
	CheckIfFileExists ${manifest_template_fname}
	CheckIfFileExists ${executable_path}
	manifest_fname="${executable_path}.manifest"
	manifest_sgx_fname="${executable_path}.manifest.sgx"
	log_file=$executable_path
	log_file+=".gramine.log"
	gramine-manifest -Dlog_level=$log_level  -Dentrypoint=$executable_path -Dlog_file=${log_file} ${manifest_template_fname} ${manifest_fname}
	[[ $? -ne 0 ]] && exit 1
	echo "Created manifest file ${manifest_fname}"
	gramine-sgx-sign --manifest ${manifest_fname} --output ${manifest_sgx_fname}
	[[ $? -ne 0 ]] && exit 1
	echo "Created sgx file ${manifest_sgx_fname}"
	echo "===done==="
}


CreateManifestsRecursively() {
	manifest_template_fname=$1
	dir_path=$2
	log_level=$3
	CheckIfDirExists ${dir_path}
	mapfile -t files < <(find ${dir_path} -type f -perm /u=x,g=x,o=x -exec ls -l {} \; | awk '{print $NF}')
	mapfile -t sym_links < <(find ${dir_path} -type l -perm /u=x,g=x,o=x -exec ls -l {} \; | awk '{print $(NF-2)}')
	arr=(${files[@]} ${sym_links[@]})
	echo "Manifests would be created for below list of executables"
	for i in "${arr[@]}"; do
		executable_path=$(echo $i|tr -d '\n')
		echo ${executable_path}
	done
	read -p "Continue?" confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

	for i in "${arr[@]}"; do
		executable_path=$(echo $i|tr -d '\n')
		CreateManifestForSingleExecutable $manifest_template_fname $executable_path $log_level
	done
	echo "===done==="
}


GetManifestFilesList() {
	dir_path=$1
	mapfile -t files_list < <(find ${dir_path} -name "*.manifest")
}

GetManifestSGXFilesList() {
	dir_path=$1
	mapfile -t files_list < <(find ${dir_path} -name "*.manifest.sgx")
}

GetManifestSigFilesList() {
	dir_path=$1
	mapfile -t files_list < <(find ${dir_path} -name "*.sig")
}

RemoveFiles() {
	files_list = $1
		echo "Below list of manifest files would be removed"
		for fname in "${files_list[@]}"; do
			echo "${fname}"
		done
		read -p "Continue?" confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
		for fname in "${files_list[@]}"; do
			rm -fr ${fname}
		done
}

CleanupManifestsRecursively() {
	dir_path=$1
	GetManifestFilesList $dir_path
	[[ ${#files_list[@]} -ne 0 ]] && RemoveFiles $files_list
	GetManifestSGXFilesList $dir_path
	[[ ${#files_list[@]} -ne 0 ]] && RemoveFiles $files_list
	GetManifestSigFilesList $dir_path
	[[ ${#files_list[@]} -ne 0 ]] && RemoveFiles $files_list
	echo "===done==="
}

Setup() {
	mkdir tmp_mount_point_for_sgx_enclave
	chmod -R 766 tmp_mount_point_for_sgx_enclave
	mkdir plain_disk_for_sgx_enclave
	chmod -R 766 plain_disk_for_sgx_enclave
	mkdir encrypted_disk_for_sgx_enclave
	chmod -R 766 encrypted_disk_for_sgx_enclave
}

Cleanup() {
	rm -fr tmp_mount_point_for_sgx_enclave
	rm -fr plain_disk_for_sgx_enclave
	rm -fr encrypted_disk_for_sgx_enclave
}

case "$1" in
  -s|--single)
	[[ "$#" -ne 4 ]] && Usage
	manifest_template_fname=$(echo $2|tr -d '\n')
	executable_path=$(echo $3|tr -d '\n')
	log_level=$4
	Setup
	CreateManifestForSingleExecutable $manifest_template_fname $executable_path $log_level
  ;;
  
  -r|--recursive)
	[[ "$#" -ne 4 ]] && Usage
  	manifest_template_fname=$(echo $2|tr -d '\n')
	dir_path=$(echo $3|tr -d '\n')
	log_level=$4
	Setup
	CreateManifestsRecursively $manifest_template_fname $dir_path $log_level
  ;;
  
  -c|--cleanup)
  	[[ "$#" -ne 2 ]] && Usage
	dir_path=$(echo $2|tr -d '\n')
	CleanupManifestsRecursively $dir_path
  ;;
  
  *) Usage;;
esac
