--- === TaskHammer ===
---
--- Run scripts from the Menu Bar
---

local obj = {}

obj.__index = obj

-- Metadata
obj.name = "TaskHammer"
obj.version = "0.0.1"
obj.author = "Joe Miller <joe@joemiller.me>"
obj.homepage = "https://github.com/joemiller/taskhammer"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("TaskHammer")

--- TaskHammer.tasks
--- Variable
--- Table containing tasks and their configuration options. Each task is itself a table with the following keys:
---
---  * name - Required. A name for the task to be displayed in the menu bar dropdown list.
---  * cmd - Required. Path to executable or script to run.
---  * args - If given, a table in array format containing arguments to pass to cmd
---  * env - If given, a table in key=value format containing environment variables to be added to the cmd's execution environment. By default environment variables are inherited from Hammerspoon. Variables specified here are *added* to this set.
---  * prompts - If given, a table containing one or more prompts to display to the user. Inputs from these prompts are added to the environment before executing the cmd. Each prompt is itself a table with the following keys:
---    * envvar - Required. The name of the environment variable to store the input into.
---    * description - A friendly message to display to the user describing the expected input value.
--- Examples:
--- ```
--- tasks = {
---     {
---         name = "simple task",
---         cmd = "/path/to/script.sh",
---     },
---     {
---         name = "task with arguments",
---         cmd = "/path/to/script.sh",
---         args = {"foo", "bar"},
---     },
---     {
---         name = "task with extra env vars",
---         cmd = "/path/to/script.sh",
---         env = {
---             FOO = "BAR",
---             BAZ = "blah"
---         }
---     },
---     {
---         name = "test prompt",
---         cmd = "/usr/bin/env",
---         prompts = {
---             {
---                 envvar = "FOOBAR",
---                 description = "1password pass"
---             },
---             {
---                 envvar = "ANOTHER_ONE",
---                 description = "another input"
---             }
---         }
---     },
---     {
---         name = "Restic Backup",
---         cmd = "/Users/joe/backup-scripts/backup.sh",
---         env = {
---             SSH_AUTH_SOCK = "/Users/joe/.gnupg/S.gpg-agent.ssh"
---         },
---         prompts = {
---             {
---                 envvar = "RESTIC_PASSWORD",
---                 description = "Please enter the Restic repository password"
---             }
---         }
---     },
--- }
--- ```
obj.tasks = {}

function obj:menuItems()
    self.logger.d("menuItems called, tasks:", hs.inspect(self.tasks))

    local entries = {
        {title = "TaskHammer", disabled = true},
        {title = "-"}
    }

    for i, task in ipairs(self.tasks) do
        if task.name == nil then
            self.logger.ef("task %d is missing 'name' attribute", i)
            goto continue
        end

        if task.cmd == nil then
            self.logger.ef("task %d is missing 'cmd' attribute", i)
            goto continue
        end

        if task.args == nil then
            task.args = {}
        end

        -- create a new webView for the task's output if one has not been created yet
        if task.outputView == nil then
            task.outputView = self.newTextWindow(task.name)
            task.outputView:html("<pre>Output will appear after the task has Run to completion</pre>")
        end

        -- refreshFn = hs.timer.delayed.new(2, function()
        --             self.logger.d("refreshFn callback called")
        --             if (task.stdoutView == nil or task.stderrView == nil) then
        --                 self.logger.d("stdoutView is nil")
        --                 return false
        --             end
        --             task.stdoutView:html('<pre>' .. task.stdout .. '</pre>')
        --             task.stderrView:html('<pre>' .. task.stderr .. '</pre>')
        --             return true
        --         end
        --         )

        if task._task == nil then
            task._task =
                hs.task.new(
                -- path to file to execute:
                task.cmd,
                -- completion callback:
                function(exitcode, stdout, stderr)
                    local status = exitcode == 0 and "Success!" or "Failed!"

                    hs.notify.new(
                        function()
                            task.outputView:show()
                        end,
                        {title = task.name, subTitle = status}
                    ):send()

                    task.lastExitCode = exitcode
                    task.lastExitReason = task._task:terminationReason()
                    task.lastStopTime = os.time()
                    task.lastDuration = (task.lastStopTime - task.lastStartTime)
                    -- task.stdout = stdout
                    -- task.stderr = stderr
                    -- task.stdoutView:html('<pre>' .. stdout .. '</pre>')
                    -- task.stderrView:html('<pre>' .. stderr .. '</pre>')
                    -- task.stdoutView:html('<pre>' .. task.stdout .. '</pre>')
                    -- task.stderrView:html('<pre>' .. task.stderr .. '</pre>')
                    -- TODO(joe): this crazy pyramid is from the lua fmt'er (https://github.com/trixnz/lua-fmt). Figure out a cleaner way to do this.
                    task.outputView:html(
                        "<pre>** Stderr **:\n" ..
                            stderr ..
                                "</pre>" ..
                                    "<pre>** Stdout **:\n" ..
                                        stdout ..
                                            "</pre>" ..
                                                "<pre>** Exit Code **:\n" ..
                                                    exitcode ..
                                                        "</pre>" ..
                                                            "<pre>** Duration (minutes) **:\n" ..
                                                                string.format("%.2f", (task.lastDuration / 60)) ..
                                                                    "</pre>"
                    )
                    -- print(task.combined_output)
                    -- refreshFn:stop()

                    -- hs.task can only be used once, so we delete ourselves after a run. The next
                    -- time the menu is constructed a new hs.task object will be created.
                    task._task = nil
                end,
                -- streaming callback:
                -- TODO: bug in streaming callback: https://github.com/Hammerspoon/hammerspoon/issues/1782
                -- function(task, stdout, stderr)
                --     self.logger.d("stream callback called")
                --     -- refreshFn:start()
                --     -- task.combined_output = task.combined_output .. stdout .. stderr
                --     -- task.stdout = task.stdout .. stdout
                --     -- task.stderr = task.stderr .. stderr
                --     return true
                -- end,
                -- optional args to pass to cmd:
                task.args
            ) -- :closeInput()
            -- add any additional env vars specified in the config to the task's inherited environment
            if task.env ~= nil then
                local env = task._task:environment()
                for k, v in pairs(task.env) do
                    env[k] = v
                end
                task._task:setEnvironment(env)
            end
        end

        task.startFn = function()
            self.logger.df("task %s (%s) starting", task.name, task.cmd)
            -- process any prompts now and add them to the task's environment
            if task.prompts ~= nil then
                local env = task._task:environment()
                for _, p in pairs(task.prompts) do
                    local _, input = hs.dialog.textPrompt(p.envvar, p.description, "", "", "", true)
                    env[p.envvar] = input
                end
                task._task:setEnvironment(env)
            end

            -- task.outputView:html('<pre>Running. Output will be shown when task is finished</pre>')
            -- task.stdout = ""
            -- task.stderr = ""
            -- task.combined_output = ''
            -- refreshFn:start()
            if not task._task:start() then
                task.outputView:html("<pre>Open the Hammerspoon console to view the error message</pre>")
                hs.notify.new(
                    {
                        title = task.name,
                        subTitle = "FAILED to start",
                        informativeText = "See Hammerspoon console for error"
                    }
                ):send()
            end
            task.lastStartTime = os.time()
        end

        task.stopFn = function()
            task._task:terminate()
        end

        local isRunning = task._task:isRunning()
        local lastRunDate = task.lastStopTime == nil and "never" or os.date("%c", task.lastStopTime)
        local lastDuration = task.lastDuration == nil and 0 or task.lastDuration
        task.subMenu = {
            {
                title = "Run" .. (task.prompts == nil and "" or "..."),
                fn = task.startFn,
                disabled = isRunning
            },
            {
                title = "Stop",
                fn = task.stopFn,
                disabled = not isRunning
            },
            {
                title = "Show Output From Last Run...",
                fn = function()
                    task.outputView:show()
                end
            },
            {title = "-"}, -- --------------
            {
                title = string.format("Last Run: %s", lastRunDate),
                indent = 1,
                disabled = true
            },
            {
                title = string.format("Last Duration: %0.2f min", (lastDuration / 60)),
                indent = 1,
                disabled = true
            },
            {
                title = string.format("Last Exit Code: %s", task.lastExitCode),
                indent = 1,
                disabled = true
            },
            {
                title = string.format("Last Exit Reason: %s", task.lastExitReason),
                indent = 1,
                disabled = true
            }
        }
        -- Add this task to the main dropdown
        table.insert(
            entries,
            {
                title = task.name .. (isRunning and " (running)" or ""),
                menu = task.subMenu
            }
        )
        ::continue::
    end

    print(hs.inspect(entries)) -- TODO debug remove
    print(hs.inspect(self.tasks)) -- TODO debug remove
    return entries
end

function obj.newTextWindow(title)
    local screenFrame = hs.screen.mainScreen():frame()
    local width = screenFrame["w"] / 3
    local height = screenFrame["h"] / 3
    local view =
        hs.webview.new(
        {
            x = (screenFrame["h"] / 2 - height),
            y = (screenFrame["w"] / 2 - width),
            w = width,
            h = height
        }
    )

    view:windowTitle(title)
    view:windowStyle({"titled", "resizable", "closable", "utility", "HUD"})
    view:darkMode(true)
    view:shadow(true)
    view:allowMagnificationGestures(true)
    view:allowNewWindows(false)
    view:level(hs.drawing.windowLevels.modalPanel)
    return view
end

--- TaskHammer:start()
--- Method
--- Start the application. The menu bar icon will appear.
function obj:start()
    self:stop()
    self.menu = hs.menubar.new()
    local icon =
        hs.image.imageFromPath(
        "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarUtilitiesFolder.icns"
    )
    self.menu:setIcon(icon:setSize({w = 16, h = 16}))
    self.menu:setMenu(hs.fnutils.partial(self.menuItems, self))
end

--- TaskHammer:stop()
--- Method
--- Stop the application. The menu bar icon will disappear. All running tasks will be terminated.
function obj:stop()
    self.logger.d("stop called")
    if self.menu then
        self.menu:removeFromMenuBar()
    end

    for _, task in pairs(self.tasks) do
        if task.stopFn ~= nil then
            self.logger.d("attempting to stop running task: ", task.name)
            task.stopFn()
        end
    end
end

return obj
