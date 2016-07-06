module Daemon

import Julimaps.Cloud.Queue
import Julimaps.Cloud.Bucket
import Julimaps.Cloud.DaemonTask

export DaemonService
export run

type DaemonService
    queue::Queue.QueueService
    bucket::Bucket.BucketService
    poll_frequency_seconds::Int64
    tasks::Dict{AbstractString, Module}
end

function run(daemon::DaemonService)
    while true
        try
            message = Queue.pop_message(daemon.queue)

            if isempty(message)
                println("No messages found in $(Queue.string(daemon.queue))")
            else
                #=task = DaemonTask.parse(message)=#
                task_module = parse(daemon, message)

                task = task_module.parse(message)

                success = task_module.execute(task)

                task = parse(daemon, message)

                println("Task is $(task.taskId)")

                #=DaemonTask.execute(task)=#
            end
        catch e
            showerror(STDERR, e, catch_backtrace(); backtrace = true)
            println(STDERR) #looks like showerror doesn't include a newline
        end

        sleep(daemon.poll_frequency_seconds)
    end
end

"""
    register(daemon::DaemonService, task_module::Module)

Register a module as a task to perform for input daemon.

# Arguments
* `daemon::DaemonService`: the daemon we are registering to
* `task_module::Module`: Module we are registering. Module **must implement**
the following interface:
** `task_type::Type`: type that includes payload
** `name::AbstractString`: name of this task
** `function execute(task::task_type)`:  function that executes task_type
*** returns Bool - true on success
** `function parse(message::any)`: function that takes expected payload and convert
*** returns task_type
*** throws ErrorException on parse error
# Returns
* task_module::Module module that implements this interface
"""
function register(daemon::DaemonService, task_module::Module)
    symbols = names(task_module, true)

    # Much rather use :in, but doesn't seem to work with array of symbols
    if findfirst(symbols, :task_type) <= 0
        error("Module $task_module does not contain :task_type defined")
    end

    if findfirst(symbols, :execute) <= 0
        error("Module $task_module does not contain an :execute function")
    end

    if findfirst(symbols, :name) <= 0
        error("Module $task_module does not contain a task :name")
    end

    #=
     =if !task_module.task_type <: DaemonTask.DaemonTaskDetails
     =    error("Module $task_module's task type does not subtype
     =        DaemonTaskDetails")
     =end
     =#

    return daemon.tasks[task_module.name]
end

function parse(daemon::DaemonService, text::ASCIIString)
    text = strip(text)

    if isempty(text)
        error("Trying to parse empty string for task")
    end

    message = JSON.parse(text)

    if !haskey(message, "details")
        error("Could not find task details from parsing message ($text)")
    end

    if !haskey(message["details"], "id")
        error("Could not find task id from parsing message ($text)")
    end

    if !haskey(message["details"], "name")
        error("Could not find task name from parsing message ($text)")
    end

    task_name = message["details"]["name"]

    if !haskey(daemon.tasks, task_name)
        error("Task $task_name is not registered with the daemon")
    end

    task_module = daemon.tasks[task_name]

    if !haskey(message, "payload")
        error("Could not find task payload from parsing message ($text)")
    end

    task = task_module.to_daemon_task(message["payload"])

    #=task_module.execute(task)=#

    return task
end

end # end module Daemon
