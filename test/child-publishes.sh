#!/bin/sh
# A child of this pom, built under the release profile, must have the publishing plugin with its extension in
# its own build - not only in pluginManagement. Without the extension, 'deploy' falls back to maven-deploy-plugin,
# which has nowhere to deploy to, and no repository built on this parent can publish.
#
# Run from the repository root: test/child-publishes.sh [maven command, default ./mvnw]
set -eu
MVN="${1:-./mvnw}"
ROOT="$(pwd)"
VERSION="$(sed -n 's|^    <version>\(.*\)</version>$|\1|p' pom.xml | head -1)"
CHILD="$ROOT/target/child-publishes"
rm -rf "$CHILD"
mkdir -p "$CHILD"
cat > "$CHILD/pom.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.fuin.sokar</groupId>
        <artifactId>sokar-parent</artifactId>
        <version>$VERSION</version>
        <relativePath>../../pom.xml</relativePath>
    </parent>
    <artifactId>child-publishes</artifactId>
    <packaging>pom</packaging>
</project>
EOF
"$MVN" -B -q -s settings.xml -f "$CHILD/pom.xml" help:effective-pom -Pcentral-sonatype-release \
    -Doutput="$CHILD/effective-pom.xml"
python3 -I - "$CHILD/effective-pom.xml" <<'EOF'
import sys
import xml.etree.ElementTree as ET
ns = {"m": "http://maven.apache.org/POM/4.0.0"}
build = ET.parse(sys.argv[1]).getroot().find("m:build", ns)
for plugin in build.findall("m:plugins/m:plugin", ns):
    if plugin.findtext("m:artifactId", "", ns) == "central-publishing-maven-plugin":
        if plugin.findtext("m:extensions", "", ns) == "true":
            print("OK    a child built under -Pcentral-sonatype-release has central-publishing-maven-plugin as an extension")
            sys.exit(0)
        print("FAULT a child has central-publishing-maven-plugin, but not as an extension: deploy would not use it")
        sys.exit(1)
print("FAULT a child built under -Pcentral-sonatype-release has no central-publishing-maven-plugin in its build"
      " (only in pluginManagement, if at all): deploy would fall back to maven-deploy-plugin")
sys.exit(1)
EOF
