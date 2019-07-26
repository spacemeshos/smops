/* Call a shell script and return stdout */
def call(args) {
  def cmd

  if(args instanceof Map && "cmd" in args) {
    cmd = args.cmd
  } else {
    cmd = args
  }

  return sh(returnStdout: true, script: cmd).trim()
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
