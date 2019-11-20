/* Generate random hex string */
def rnd = new Random()

def call() {
  String.format("%06x",(rnd.nextFloat() * 2**31) as Integer)[0..5]
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
