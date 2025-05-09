#!/bin/bash

# Log file path
LOG_FILE="$1"

# Check if log file exists
if [[ ! -f "$LOG_FILE" ]]; then
  echo "File not found: $LOG_FILE"
  exit 1
fi

# 1. Request Counts
TOTAL_REQUESTS=$(wc -l < "$LOG_FILE")
GET_REQUESTS=$(grep '"GET' "$LOG_FILE" | wc -l)
POST_REQUESTS=$(grep '"POST' "$LOG_FILE" | wc -l)
OTHER_REQUESTS=$(grep -vE '"(GET|POST)' "$LOG_FILE" | grep -E '"[A-Z]+' | wc -l)

# Output the request counts
echo "1. Request Counts"
echo "----------------"
echo "Total Requests:    $TOTAL_REQUESTS"
echo "GET Requests:      $GET_REQUESTS"
echo "POST Requests:     $POST_REQUESTS"
echo "Other Requests:    $OTHER_REQUESTS"
echo ""
# 2. Unique IP Addresses
echo "2. Unique IP Addresses"
echo "-----------------------"
ips=$(awk '{print $1}' "$LOG_FILE" | sort -u)
echo "Total Unique IPs: $(echo "$ips" | wc -l)"

# print header
printf "%-15s %8s %8s\n" "IP" "GET" "POST"

# for each IP, count GET and POST
for ip in $ips; do
  get_count=$(grep "^$ip " "$LOG_FILE" | grep -c '"GET ')
  post_count=$(grep "^$ip " "$LOG_FILE" | grep -c '"POST ')
  printf "%-15s %8d %8d\n" "$ip" "$get_count" "$post_count"
done

# total unique
echo ""
echo "Total Unique IPs: $(echo "$ips" | wc -l)"


echo "3. Failure Requests"
echo "-------------------"

# count 4xx and 5xx status codes
FAIL4=$(grep -E '" [4][0-9][0-9]' "$LOG_FILE" | wc -l)
FAIL5=$(grep -E '" [5][0-9][0-9]' "$LOG_FILE" | wc -l)
FAIL_TOTAL=$(( FAIL4 + FAIL5 ))



# compute percentage with awk
FAIL_PCT=$(awk -v f="$FAIL_TOTAL" -v t="$TOTAL_REQUESTS" 'BEGIN { printf "%.2f", (f/t)*100 }')

echo "4xx failures:    $FAIL4"
echo "5xx failures:    $FAIL5"
echo "Total failures:  $FAIL_TOTAL ($FAIL_PCT% of total)"
echo ""

# 4. Top User
echo "4. Top User"
echo "------------"

# find the IP that appears most often in field 1
top_ip=$(awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -n1)

# awk outputs: “<count> <ip>”
count=$(echo "$top_ip" | awk '{print $1}')
ip=$(echo "$top_ip" | awk '{print $2}')

echo "Most active IP: $ip with $count requests"
echo ""

# 5. Daily Request Averages
echo "5. Daily Request Averages"
echo "-------------------------"

# extract the date (YYYY‑MM‑DD) from the timestamp in field 4, count per day
# then compute average = total_requests / number_of_days
read total_requests days average_per_day <<< $(awk '
    {
      # remove leading “[”
      gsub(/^\[/, "", $4)
      # split on “:”, first element is date string “dd/MMM/yyyy”
      split($4, a, ":")
      day = a[1]
      counts[day]++
    }
    END {
      # convert dates from dd/MMM/yyyy to yyyy‑MM‑DD for readability
      # count days and total requests
      tot = NR
      d = length(counts)
      avg = (d>0 ? tot/d : 0)
      # print total, days, average
      printf "%d %d %.2f\n", tot, d, avg
    }
' "$LOG_FILE")

echo "Number of days:      $days"
echo "Average per day:     $average_per_day"
echo ""
          
# 6. Failure Analysis
echo "6. Failure Analysis"
echo "-------------------"

# find all 4xx or 5xx, extract date, count per date, sort by count desc, show top 5
grep -E '" [45][0-9][0-9]' "$LOG_FILE" | \
  awk '{ gsub(/^\[/,"",$4); split($4,d,":"); print d[1] }' | \
  sort | uniq -c | sort -rn | head -5 | \
  awk '{ printf "%s — %d failures\n", $2, $1 }'

echo ""

# Request by Hour for Each Day
echo "Request by Hour (per day)"
echo "-------------------------"

awk '
  {
    # strip leading “[” from timestamp field
    gsub(/^\[/, "", $4)
    # split on “:”, so a[1]=dd/MMM/yyyy, a[2]=HH
    split($4, a, ":")
    day  = a[1]
    hour = a[2]
    cnt[day][hour]++
    seen[day] = 1
  }
  END {
    # ensure days sorted chronologically
    n = asorti(seen, days)
    for (i = 1; i <= n; i++) {
      d = days[i]
      print "\n" d
      for (h = 0; h < 24; h++) {
        hh = sprintf("%02d", h)
        printf "  %s:00 - %d\n", hh, cnt[d][hh] + 0
      }
    }
  }
' "$LOG_FILE"

echo ""

# ——— Request Trends ———
echo "Request Trends"
echo "--------------"

# 1) Daily totals and day‑to‑day change
echo
echo "By Day (total requests and change vs previous day):"
# build day→count
declare -A day_count
while read -r line; do
  # remove leading '[' from field 4, split on ':' to isolate day
  ts=${line#*[}
  day=${ts%%:*}
  (( day_count[$day]++ ))
done < "$LOG_FILE"

# sort days in chronological order (assumes dd/MMM/yyyy format)
days=($(printf "%s\n" "${!day_count[@]}" | sort -t/ -k3,3n -k2,2M -k1,1n))

prev=
printf "%-12s %8s %12s\n" "Day" "Total" "Δ from prev"
for d in "${days[@]}"; do
  cnt=${day_count[$d]}
  if [[ -n $prev ]]; then
    delta=$(( cnt - day_count[$prev] ))
    sign=$([[ $delta -ge 0 ]] && echo "+" || echo "")
  else
    delta="—"
    sign=""
  fi
  printf "%-12s %8d %s%4s\n" "$d" "$cnt" "$sign" "$delta"
  prev=$d
done

# 2) Hourly average across all days
echo
echo "By Hour (average requests per hour across all days):"
# build hour→count, and count of days
declare -A hour_total
for d in "${days[@]}"; do
  # for each day, count per‑hour
  while read -r line; do
    ts=${line#*[}
    day=${ts%%:*}
    if [[ $day == "$d" ]]; then
      hour=${ts#*:}; hour=${hour%%:*}
      (( hour_total[$hour]++ ))
    fi
  done < "$LOG_FILE"
done

# average = total_for_hour / number_of_days
num_days=${#days[@]}
printf "%-5s %10s\n" "Hour" "Avg/Day"
for h in $(seq -w 0 23); do
  total=${hour_total[$h]:-0}
  avg=$(awk -v t="$total" -v d="$num_days" 'BEGIN { printf "%.2f", t/d }')
  printf "%-5s %10s\n" "$h:00" "$avg"
done

echo

# 3) Peak Day & Peak Hours
echo
echo "Peak Day & Peak Hours"
echo "----------------------"

# find peak day from day_count[]
peak_day=$(for d in "${!day_count[@]}"; do
  printf "%d %s\n" "${day_count[$d]}" "$d"
done | sort -rn | head -n1 | awk '{print $2}')
peak_day_total=${day_count[$peak_day]:-0}

echo "Peak day: $peak_day with $peak_day_total requests"
echo

# now find peak hours on that day
echo "Top 3 hours on $peak_day:"
grep "\[$peak_day:" "$LOG_FILE" | \
  awk '{ gsub(/^\[/,"",$4); split($4,a,":"); print a[2] }' | \
  sort | uniq -c | sort -rn | head -n3 | \
  awk '{ printf "  %02d:00 — %d requests\n", $2, $1 }'
echo ""

# Status Codes Breakdown
echo "Status Codes Breakdown"
echo "----------------------"

# Extract the status code (field 9) from each line, tally and sort
awk '{ print $9 }' "$LOG_FILE" | \
  sort | uniq -c | sort -rn | \
  awk '{ printf "%s: %d\n", $2, $1 }'

echo ""

# Most Active User by Method
echo "Most Active User by Method"
echo "--------------------------"

# Top GET
top_get=$(grep '"GET ' "$LOG_FILE" | awk '{print $1}' | sort | uniq -c | sort -rn | head -n1)
get_count=$(echo "$top_get" | awk '{print $1}')
get_ip=$(echo "$top_get"   | awk '{print $2}')
echo "GET  — $get_ip with $get_count requests"

# Top POST
top_post=$(grep '"POST ' "$LOG_FILE" | awk '{print $1}' | sort | uniq -c | sort -rn | head -n1)
post_count=$(echo "$top_post" | awk '{print $1}')
post_ip=$(echo "$top_post"   | awk '{print $2}')
echo "POST — $post_ip with $post_count requests"

echo ""

# Patterns in Failure Requests
echo "Patterns in Failure Requests"
echo "----------------------------"

# A) Failures by Day
echo
echo "Failures by Day:"
day_failures=$(grep -E '" [45][0-9][0-9]' "$LOG_FILE" | \
  awk '{ gsub(/^\[/, "", $4); split($4, a, ":"); print a[1] }' | \
  sort | uniq -c | sort -rn)
echo "$day_failures" | awk '{ printf "  %s — %d failures\n", $2, $1 }'

# B) Failures by Hour (all days)
echo
echo "Failures by Hour (all days):"
hour_failures=$(grep -E '" [45][0-9][0-9]' "$LOG_FILE" | \
  awk '{ gsub(/^\[/, "", $4); split($4, a, ":"); print a[2] }' | \
  sort | uniq -c | sort -rn)
echo "$hour_failures" | awk '{ printf "  %02d:00 — %d failures\n", $2, $1 }'

# C) Peak failure day
peak_day_line=$(echo "$day_failures" | head -n1)
peak_day_count=$(echo "$peak_day_line" | awk '{print $1}')
peak_day=$(echo "$peak_day_line" | awk '{print $2}')
echo
echo "Peak failure day: $peak_day with $peak_day_count failures"

# D) Peak failure hour
peak_hour_line=$(echo "$hour_failures" | head -n1)
peak_hour_count=$(echo "$peak_hour_line" | awk '{print $1}')
peak_hour=$(echo "$peak_hour_line" | awk '{printf "%02d", $2}')
echo "Peak failure hour: ${peak_hour}:00 with $peak_hour_count failures"
echo

