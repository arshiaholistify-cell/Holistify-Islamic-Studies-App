#!/bin/sh
set -e
sed -i "s|__IS_SUPABASE_URL__|${ISLAMIC_STUDIES_SUPABASE_URL}|g" index.html
sed -i "s|__IS_SUPABASE_ANON_KEY__|${ISLAMIC_STUDIES_SUPABASE_ANON_KEY}|g" index.html
