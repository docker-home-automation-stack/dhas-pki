#!/bin/bash
set -e

if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
  exit 0
fi

echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
sleep $[ ( $RANDOM % 10 )  + 1 ]s

for VARIANT in $( docker images | grep '^homeautomationstack/*' | grep -v "<none>" | grep -P ' dev|beta|latest ' | awk '{print $2}' | uniq | sort ); do
  echo "Creating manifest file homeautomationstack/dhas-pki:${VARIANT} ..."
  docker manifest create homeautomationstack/dhas-pki:${VARIANT} \
    homeautomationstack/dhas-pki-amd64_linux:${VARIANT} \
    homeautomationstack/dhas-pki-i386_linux:${VARIANT} \
    homeautomationstack/dhas-pki-arm32v6_linux:${VARIANT} \
    homeautomationstack/dhas-pki-arm64v8_linux:${VARIANT}
  docker manifest annotate homeautomationstack/dhas-pki:${VARIANT} homeautomationstack/dhas-pki-arm32v6_linux:${VARIANT} --os linux --arch arm --variant v6
  docker manifest annotate homeautomationstack/dhas-pki:${VARIANT} homeautomationstack/dhas-pki-arm64v8_linux:${VARIANT} --os linux --arch arm64 --variant v8
  docker manifest inspect homeautomationstack/dhas-pki:${VARIANT}

  echo "Pushing manifest homeautomationstack/dhas-pki:${VARIANT} to Docker Hub ..."
  docker manifest push homeautomationstack/dhas-pki:${VARIANT}

  echo "Requesting current manifest from Docker Hub ..."
  docker run --rm mplatform/mquery homeautomationstack/dhas-pki:${VARIANT}
done

exit 0
