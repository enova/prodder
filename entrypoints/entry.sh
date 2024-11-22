#!/bin/bash
set -euo pipefail

cmd=("$@")

mkdir -p config
cat <<EOF > config/database.yml
test:
  adapter: postgresql
  encoding: unicode
  pool: 20
  database: prodder_test
EOF

exec "${cmd[@]}"
