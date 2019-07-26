def call(args) {
  int length = 6
  if(args instanceof Map && "length" in args) {
    length = args.length
  }
  if(args instanceof Integer) {
    length = args
  }

  def r = ""

  // Generate 8-char chunks as required
  if(length >= 8)
    for(x in 1..(length/8 as Integer)) {
      r += sprintf("%08x", (Math.random() * 2**31) as Integer)
    }

  // Pad with the rest
  if(length % 8 > 0) {
    def rest = length % 8
    r += sprintf("%0${rest}x",(Math.random() * 2**31) as Integer)[0..rest - 1]
  }

  return r
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
