#!/bin/bash
# cache_trim.sh - keep this pod's own disk from filling: VC3D's render cache (~/.VC3D/remote_cache, CT chunks streamed
# from S3) has no size limit. Every 2 min: below TRIM_AT GB free (15), delete cache files untouched for OLD_MIN minutes
# (30); below HARD_AT GB (5), for HARD_MIN (5). P9 10/29: with two renders on one 30 GB pod disk the defaults fell
# ~1 GB per 2 min to 7 GB free (fresh chunks are all younger than 30 min): run there with OLD_MIN=10 HARD_AT=8 HARD_MIN=2.
C=/root/.VC3D/remote_cache; TRIM_AT=${TRIM_AT:-15}; OLD_MIN=${OLD_MIN:-30}; HARD_AT=${HARD_AT:-5}; HARD_MIN=${HARD_MIN:-5}
free_gb() { df -BG --output=avail / | tail -1 | tr -dc 0-9; }
while true; do
  if [ -d $C ] && [ "$(free_gb)" -lt $TRIM_AT ]; then
    find $C -type f -mmin +$OLD_MIN -delete 2>/dev/null
    [ "$(free_gb)" -lt $HARD_AT ] && find $C -type f -mmin +$HARD_MIN -delete 2>/dev/null
    echo "$(date -u +%FT%TZ) trimmed; $(free_gb) GB free"
  fi
  sleep 120
done
