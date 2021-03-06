--!A cross-platform build utility based on Lua
--
-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2019, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        install_package.lua
--

-- imports
import("core.base.option")
import("core.project.config")
import("lib.detect.find_tool")

-- get build directory
function _conan_get_build_directory(name)
    return path.absolute(path.join(config.buildir() or os.tmpdir(), ".conan", name))
end

-- generate conanfile.txt
function _conan_generate_conanfile(name, opt)

    -- trace
    dprint("generate %s ..", path.join(_conan_get_build_directory(name), "conanfile.txt"))

    -- get conan options, imports and build_requires
    local options        = table.wrap(opt.options)
    local imports        = table.wrap(opt.imports)
    local build_requires = table.wrap(opt.build_requires)

    -- generate it
    io.writefile("conanfile.txt", ([[
[generators]
xmake
[requires]
%s
[options]
%s
[imports]
%s
[build_requires]
%s
    ]]):format(name, table.concat(options, "\n"), table.concat(imports, "\n"), table.concat(build_requires, "\n")))
end

-- install package
--
-- @param name  the package name, e.g. conan::OpenSSL/1.0.2n@conan/stable 
-- @param opt   the options, .e.g { verbose = true, mode = "release", plat = , arch = ,
--                                  remote = "", build = "all", options = {}, imports = {}, build_requires = {},
--                                  settings = {"compiler=Visual Studio", "compiler.version=10", "compiler.runtime=MD"}}
--
-- @return      true or false
--
function main(name, opt)

    -- find conan
    local conan = find_tool("conan")
    if not conan then
        raise("conan not found!")
    end

    -- get build directory
    local buildir = _conan_get_build_directory(name)

    -- clean the build directory
    os.tryrm(buildir)
    if not os.isdir(buildir) then
        os.mkdir(buildir)
    end

    -- enter build directory
    local oldir = os.cd(buildir)

    -- generate conanfile.txt
    _conan_generate_conanfile(name, opt)

    -- install package
    local argv = {"install", "."}
    if opt.build then
        if opt.build == "all" then
            table.insert(argv, "--build")
        else
            table.insert(argv, "--build=" .. opt.build)
        end
    end

    -- set platform
    table.insert(argv, "-s")
    if opt.plat == "macosx" then
        table.insert(argv, "os=Macos")
    elseif opt.plat == "linux" then
        table.insert(argv, "os=Linux")
    elseif opt.plat == "windows" then
        table.insert(argv, "os=Windows")
    else
        raise("cannot install package(%s) on platform(%s)!", name, opt.plat)
    end

    -- set architecture
    table.insert(argv, "-s")
    if opt.arch == "x86_64" or opt.arch == "x64" then
        table.insert(argv, "arch=x86_64")
    elseif opt.arch == "i386" or opt.arch == "x86" then
        table.insert(argv, "arch=x86")
    else
        raise("cannot install package(%s) for arch(%s)!", name, opt.arch)
    end

    -- set build mode
    table.insert(argv, "-s")
    if opt.mode == "debug" then
        table.insert(argv, "build_type=Debug")
    else
        table.insert(argv, "build_type=Release")
    end

    -- set compiler settings
    if opt.plat == "windows" then
        local vsvers = {["2017"] = "15", ["2015"] = "14", ["2013"] = "12", ["2012"] = "11", ["2010"] = "10", ["2008"] = "9", ["2005"] = "8"}
        local vs = assert(config.get("vs"), "vs not found!")
        table.insert(argv, "-s")
        table.insert(argv, "compiler=Visual Studio")
        table.insert(argv, "-s")
        table.insert(argv, "compiler.version=" .. assert(vsvers[vs], "unknown msvc version!"))
    end

    -- set custom settings
    for _, setting in ipairs(opt.settings) do
        table.insert(argv, "-s")
        table.insert(argv, setting)
    end

    -- set remote
    if opt.remote then
        table.insert(argv, "-r")
        table.insert(argv, opt.remote)
    end

    -- do install
    os.vrunv(conan.program, argv)

    -- leave build directory
    os.cd(oldir)
end
