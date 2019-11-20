/* Generate random hex string */
def call() {
  def rnd = new Random()
  String.format("%06x",(rnd.nextFloat() * 2**31) as Integer)[0..5]
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
