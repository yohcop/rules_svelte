"Implementation of bundle_prod rule."

load("//internal:copy-files.bzl", "copy_files")
load("//internal:get-config.bzl", "get_config")

def _bundle_prod(ctx):
    output_dir_bundles = ctx.actions.declare_directory("bundles")

    if not ctx.file.closure_config == None:
        rootFolder = ctx.file.entry_point.path.replace(ctx.file.entry_point.basename, "")

        argsClosure = [output_dir_bundles.path]
        argsClosure.append(ctx.bin_dir.path + "/" + rootFolder)
        argsClosure.append(ctx.attr._java[java_common.JavaRuntimeInfo].java_executable_exec_path)
        argsClosure.append(rootFolder)
        
        closure_files = copy_files(ctx)

        ctx.actions.run(
            executable = ctx.executable._closure,
            inputs = closure_files,
            outputs = [output_dir_bundles],
            arguments = argsClosure,
        )

    else:    
        files = copy_files(ctx)

        config = get_config(ctx)
        files.append(config)

        non_minified = ctx.actions.declare_file("temp.js")
        
        args = ctx.actions.args()
        args.add_all(["--config", config.path])
        args.add_all(["--input", ctx.bin_dir.path + "/" + ctx.build_file_path.replace("BUILD.bazel", "") + "/build-output/src/" + ctx.file.entry_point.path])
        args.add_all(["--file", non_minified.path])

        ctx.actions.run(
            executable = ctx.executable._rollup,
            inputs = files,
            outputs = [non_minified],
            arguments = [args],
        )

        args_terser = [non_minified.path]
        args_terser += ["--output", output_dir_bundles.path + "/bundle.min.js"]

        ctx.actions.run(
            executable = ctx.executable._terser,
            inputs = [non_minified],
            outputs = [output_dir_bundles],
            arguments = args_terser,
        )

    return DefaultInfo(runfiles=ctx.runfiles([output_dir_bundles]))

bundle_prod = rule(
    implementation = _bundle_prod,
    attrs = {
        "deps": attr.label_list(),
        "entry_point": attr.label(allow_single_file = True),
        "closure_config": attr.label(allow_single_file = True),
        "_java": attr.label(executable = False, allow_files = True, default = Label("@bazel_tools//tools/jdk:current_java_runtime")), 
        "_svelte_deps": attr.label(executable = False, allow_files = True, default = Label("//internal:svelte_deps")),
        "_rollup": attr.label(executable = True, cfg = "host", default = Label("//internal:rollup_bin")),
        "_closure": attr.label(executable = True, cfg = "host", default = Label("//internal:closure_bin")),
        "_terser": attr.label(executable = True, cfg = "host", default = Label("//internal:terser")),
        "_config": attr.label(
            executable = True,
            cfg = "host",
            default = Label("//internal:create_config"),
        )
      
    }
)
