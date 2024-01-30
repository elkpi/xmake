--!A cross-platform build utility based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Copyright (C) 2015-present, TBOOX Open Source Group.
--
-- @author      ruki, Arthapz
-- @file        msvc/dependency_scanner.lua
--

-- imports
import("core.base.json")
import("core.base.semver")
import("core.project.depend")
import("private.tools.vstool")
import("utils.progress")
import("compiler_support")
import("builder")
import(".dependency_scanner", {inherit = true})

-- generate dependency files
function generate_dependencies(target, sourcebatch, opt)
    local msvc = target:toolchain("msvc")
    local scandependenciesflag = compiler_support.get_scandependenciesflag(target)
    local ifcoutputflag = compiler_support.get_ifcoutputflag(target)
    local common_flags = {"-TP", scandependenciesflag}
    local changed = false

    for _, sourcefile in ipairs(sourcebatch.sourcefiles) do
        local dependfile = target:dependfile(sourcefile)
        depend.on_changed(function ()
            progress.show(opt.progress, "${color.build.target}<%s> generating.module.deps %s", target:name(), sourcefile)
            local outputdir = compiler_support.get_outputdir(target, sourcefile)

            local jsonfile = path.join(outputdir, path.filename(sourcefile) .. ".module.json")
            if scandependenciesflag and not target:policy("build.c++.msvc.fallbackscanner") then
                local flags = {jsonfile, sourcefile, ifcoutputflag, outputdir, "-Fo" .. target:objectfile(sourcefile)}
                local compinst = target:compiler("cxx")
                local msvc = target:toolchain("msvc")
                local compflags = table.join(compinst:compflags({sourcefile = sourcefile, target = target}) or {}, common_flags, flags)
                local _, err = os.iorunv(compinst:program(), winos.cmdargv(compflags), {envs = msvc:runenvs()})
                assert(err, err)
            else
                fallback_generate_dependencies(target, jsonfile, sourcefile, function(file)
                    local compinst = target:compiler("cxx")
                    local compflags = compinst:compflags({sourcefile = file, target = target})
                    local ifile = path.translate(path.join(outputdir, path.filename(file) .. ".i"))
                    local _, err = os.iorunv(compinst:program(), table.join(compflags,
                        {"/P", "-TP", file,  "/Fi" .. ifile}), {envs = msvc:runenvs()})
                    assert(err, err)
                    local content = io.readfile(ifile)
                    os.rm(ifile)
                    return content
                end)
            end
            changed = true

            local dependinfo = io.readfile(jsonfile)
            return { moduleinfo = dependinfo }
        end, {dependfile = dependfile, files = {sourcefile}, changed = target:is_rebuilt()})
    end
    return changed
end

