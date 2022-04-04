println("               [1m[32m_[0m")
println("   [1m[34m_[0m       [0m_[0m [1m[31m_[1m[32m(_)[1m[35m_[0m     |  Documentation: https://docs.julialang.org")
println("  [1m[34m(_)[0m     | [1m[31m(_)[0m [1m[35m(_)[0m    |")
println("   [0m_ _   _| |_  __ _[0m   |")
println("  [0m| | | | | | |/ _  |[0m  |")
println("  [0m| | |_| | | | (_| |[0m  |")
println(" [0m_/ |\\__|_|_|_|\\__|_|[0m  |  ")
println("[0m|__/[0m                   |")

# Only get color if using PTY. Also, get issue with ` string character
#Base.banner(stdout)  
println("")
while (true)
    #print("julia> ");flush(stdout)
    print("[32m[1mjulia> [0m");flush(stdout)
    s=readline()
    if s=="exit"
        exit(0)
    end
    try
        e=Meta.parse(s)
        result=eval(e)
        if typeof(result) !== Nothing
            println(result)
        end
    catch e
        println(e)
    end
    println("")
end
