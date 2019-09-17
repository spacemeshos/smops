/* Library function: call script and return stdout */
def call(String cmd) {
  sh(returnStdout: true, script: cmd).trim()
}

/* vim:set filetype=groovy ts=2 sw=2 et: */
