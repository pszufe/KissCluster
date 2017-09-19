#!/usr/local/bin/julia

println("Running job " * ARGS[1])
println(gethostname())
println(now())
println("wait")
sleep(2)
println(gethostname())
println(now())
println("End of job " * ARGS[1])
