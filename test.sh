#!/bin/bash

# Function to check the health of the service with a timeout of 80 seconds
check_health() {
    local service_name=$1
    local compose_file=$2
    local end=$((SECONDS+60))

    echo -n "Waiting for $service_name to become healthy..."
	until [ "$(docker inspect --format='{{json .State.Health.Status}}' "$service_name")" == '"healthy"' ] || [ $SECONDS -ge $end ]; do
		sleep 3
		echo -n "."
		if [ $SECONDS -ge $end ]; then
			echo -e "\n$service_name health check timed out after 80 seconds."
			echo "Printing logs for $service_name:"
            docker logs "$service_name"
			return 1
		fi
	done
	echo -e "\n$service_name is healthy!"

    return 0
}

# Function to test a Docker Compose configuration
test_compose() {
    local compose_file=$1
    local service_name=$2
    local status=0

    echo "Testing $compose_file configuration..."

    # Start up the Docker Compose service
    docker-compose -f "$compose_file" up -d

    # Wait for the service to become healthy
    if check_health "$service_name" "$compose_file"; then
        echo "$service_name test passed."
    else
        echo "$service_name test failed."
        status=1
    fi

    # Perform additional tests if needed

    # Tear down the service
    docker-compose -f "$compose_file" down

    return $status
}

# Keep track of which tests passed and failed
declare -a passed_tests
declare -a failed_tests

run_tests() {
    local test_name=$1
    local compose_file=$2

    if test_compose "$compose_file" "$test_name"; then
        passed_tests+=("$test_name")
    else
        failed_tests+=("$test_name")
    fi
}

# Main testing routine
main() {
	SECONDS=0
	
    export DOCKER_ENABLE_SECURITY=false
    ./gradlew clean build

    # Building Docker images
    docker build --build-arg VERSION_TAG=alpha -t frooodle/s-pdf:latest -f ./Dockerfile .
    docker build --build-arg VERSION_TAG=alpha -t frooodle/s-pdf:latest-lite -f ./Dockerfile-lite .
    docker build --build-arg VERSION_TAG=alpha -t frooodle/s-pdf:latest-ultra-lite -f ./Dockerfile-ultra-lite .

    # Test each configuration
    run_tests "Stirling-PDF-Ultra-Lite" "./exampleYmlFiles/docker-compose-latest-ultra-lite.yml"
    run_tests "Stirling-PDF-Lite" "./exampleYmlFiles/docker-compose-latest-lite.yml"
    run_tests "Stirling-PDF" "./exampleYmlFiles/docker-compose-latest.yml"

    export DOCKER_ENABLE_SECURITY=true
    ./gradlew clean build

    # Building Docker images with security enabled
    docker build --build-arg VERSION_TAG=alpha -t frooodle/s-pdf:latest -f ./Dockerfile .
    docker build --build-arg VERSION_TAG=alpha -t frooodle/s-pdf:latest-lite -f ./Dockerfile-lite .
    docker build --build-arg VERSION_TAG=alpha -t frooodle/s-pdf:latest-ultra-lite -f ./Dockerfile-ultra-lite .

    # Test each configuration with security
    run_tests "Stirling-PDF-Ultra-Lite-Security" "./exampleYmlFiles/docker-compose-latest-ultra-lite-security.yml"
    run_tests "Stirling-PDF-Lite-Security" "./exampleYmlFiles/docker-compose-latest-lite-security.yml"
    run_tests "Stirling-PDF-Security" "./exampleYmlFiles/docker-compose-latest-security.yml"

    # Report results
    echo "All tests completed in $SECONDS seconds."
	
	
	if [ ${#passed_tests[@]} -ne 0 ]; then
		echo "Passed tests:"
	fi
    for test in "${passed_tests[@]}"; do
        echo -e "\e[32m$test\e[0m"  # Green color for passed tests
    done

	if [ ${#failed_tests[@]} -ne 0 ]; then
		echo "Failed tests:"
	fi
    for test in "${failed_tests[@]}"; do
        echo -e "\e[31m$test\e[0m"  # Red color for failed tests
    done

	
	
    # Check if there are any failed tests and exit with an error code if so
    if [ ${#failed_tests[@]} -ne 0 ]; then
        echo "Some tests failed."
        exit 1
    else
        echo "All tests passed successfully."
        exit 0
    fi
	
}

main
