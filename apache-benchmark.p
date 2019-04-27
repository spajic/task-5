# Output to a jpeg file
set terminal png size 1280,720

# Set the aspect ratio of the graph
set size 1, 1

# The file to write to
set output "graphs/origin.png"

# The graph title
set title "Benchmark testing"

set xlabel "Requests"

set ylabel "Response (ms)"
set grid y

# Tell gnuplot to use tabs as the delimiter instead of spaces (default)
set datafile separator '\t'

# Plot the data
plot "tmp/origin.tsv" every ::2 using 5 title 'response time' with boxes