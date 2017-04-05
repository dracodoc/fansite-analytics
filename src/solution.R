# libraries
if (!require("pacman")) install.packages("pacman")
pacman::p_load(readr, data.table, stringr, lubridate,  ggplot2, scales)
# count time
last_time <- proc.time()
# read file
data_file <- "log_input/log.txt"
parsed <- read_log(data_file)  # 8.5 secs.
# build data table
dt <- as.data.table(parsed)
dt[, `:=`(X2 = NULL, X3 = NULL)]
setnames(dt, c("host", "time_string", "request", "status", "bytes_string"))
dt[, original_row_no := .I]
# note time was converted to UTC
dt[, timestamp := dmy_hms(time_string)]
dt[, bytes := as.numeric(bytes_string)]
cat("data table built\n")
current_time <- proc.time()
current_time - last_time
last_time <- current_time
# feature 1 ----
setkey(dt, host)
top_hosts <- na.omit(dt[, .N, by = host][order(-N)][1:10])
write_output <- function(df, file) {
  write.table(df, file = file,
              sep = ",", quote = FALSE, row.names = FALSE, col.names = FALSE)
}
write_output(top_hosts, file = "log_output/hosts.txt")
cat("feature 1 done\n")
current_time <- proc.time()
current_time - last_time
last_time <- current_time

# feature 2 ----
top_requests <- dt[, sum(bytes), by = request][order(-V1)][1:10]
re_resource <- '(GET|POST|HEAD)\\s(.+?)\\s?(HTTP\\/1\\.0)?\\"?$'
matches <- function(result){
  return(list(result[, 2], result[, 3], result[, 4]))
}
top_requests[, c("command", "resource", "protocol") :=
               matches(str_match(request, re_resource))]
write_output(na.omit(top_requests[, resource]), file = "log_output/resources.txt")
cat("feature 2 done\n")
current_time <- proc.time()
current_time - last_time
last_time <- current_time

# feature 3 ----
setkey(dt, timestamp)
hist_value <- hist(dt[, timestamp], breaks = "hours", plot = FALSE)
# breaks included the ending close edge, remove it to match the group count
break_start <- hist_value$breaks[1:(length(hist_value$breaks) - 1)]
dt_timewindow <- data.table(break_start = as_datetime(break_start),
                            counts = hist_value$counts)
top10 <- na.omit(dt_timewindow[order(-counts)][1:10])
# Etc/GMT+4 is same with EDT, this is easier to find out tz name starting from the offset number. the sign is reversed. https://en.wikipedia.org/wiki/Tz_database
# the top visits was for the space shuttle Discovery launch on 9:41 EDT
top10[, hour_window := format(top10[, break_start], "%d/%B/%Y:%H:%M:%S %z", tz = "Etc/GMT+4")]
write_output(top10[, .(hour_window, counts)], "log_output/hours.txt")
cat("feature 3 done\n")
current_time <- proc.time()
current_time - last_time
last_time <- current_time

# feature 4
login_period <- dseconds(20)
ban_period <- dminutes(5)
dt_4 <- dt[str_detect(request, "POST /login")]
# note time was converted to UTC
dt_4[, timestamp := dmy_hms(time_string)]
setkey(dt_4, host, timestamp)  # many rows have same timestamp. sort should keep the original order for equal rows
dt_4[status == "401", fail := TRUE]
dt_4[status == "200", fail := FALSE]
dt_4[, row_no := .I]
setkey(dt_4, host, timestamp, row_no)

dt_4[, banned := FALSE]
# fail_no_3 <- NULL
# c1 go through each group, exclude group with less 3 failed entries first.
multi_entry_hosts <- dt_4[(fail), .N, by = host][N >= 3, host]
for (group in multi_entry_hosts) {
  # operate in subset to reduce range, cannot filter banned here because it has not been updated in the beginning.
  in_group <- dt_4[(host == group)]
  # c3 iterate on failures, start from 3rd within each group
  fail_row_nos <- in_group[(fail), row_no]
  # we have garrantee of >= 3 rows from previous filtering
  # use r_no instead of i because it is not the index can be used directly.
  for (r_no in fail_row_nos[3:length(fail_row_nos)]) {
    # if(r_no == 16) browser()
    # c2 not banned, checked current row
    if (!in_group[row_no == r_no, banned]) { # use chained if because want to stop fast, and save some expression before reuse in conditions. must check banned in every loop instead of preparing the fail row list since that only happen once in beginning.
      # c2, check all rows in same group, the banned entries could be updated in last row check, need to update the check
      valids <- in_group[(!banned)]
      # index in group of the row to be checked
      i <- valids[row_no == r_no, which = TRUE]
      # make sure there are 2 entries before. the previous check need to be updated
      if (i >= 3) {
        # c4 no success in these 3, c5 time difference i, i-2 <= 20 secs
        if (all(valids[(i - 2):i, fail]) &&
            (valids[i, timestamp] - valids[i - 2, timestamp]
             <= login_period)) {
          # fail_no_3 <- c(fail_no_3, r_no)
          in_group[(row_no > r_no) &
                     ((timestamp - valids[i, timestamp]) <=
                        ban_period), banned := TRUE]
        }
      }
    }
  }
  # mark the original data after current group is processed
  dt_4[row_no %in% in_group[(banned), row_no], banned := TRUE]
}
banned_rows <- dt_4[(banned), original_row_no]
lines <- read_lines(data_file)
banned_lines <- lines[banned_rows]
write_lines(banned_lines, "log_output/blocked.txt")
cat("feature 4 done\n")
current_time <- proc.time()
current_time - last_time
last_time <- current_time
