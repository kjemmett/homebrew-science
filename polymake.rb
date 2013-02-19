require 'formula'

class NeedsSnowLeopard < Requirement
    fatal true
    satisfy MacOS.version >= :snow_leopard
    def message; <<-EOS.undent
        This version of polymake requires OSX 10.6 or greater. For older versions of OSX, use polymake 2.9.9, available at the polymake homepage.
        EOS
    end
end

class Javaview < Formula
  homepage 'http://www.javaview.de/index.html'
  url 'http://www.javaview.de/download/data/javaview.zip'
  version '4.0'
  sha1 'ff93022bfcd32f774ac8a18378e688d1f2acc13c'
end

class Polymake < Formula
  homepage 'http://www.polymake.org/'
  url 'http://www.polymake.org/lib/exe/fetch.php/download/polymake-2.12-rc3.tar.bz2'
  sha1 'a990ea31a68740cbf1aba02d49ec23ef589c173d'

  option '32-bit', 'Build for 32-bit architecture'
  option 'with-java', 'Build with java support'
  option 'with-javaview', 'Build with javaview support'
  option 'without-callable', "Don't build polymake callable library"

  depends_on 'readline'
  depends_on 'gmp'
  depends_on 'mpfr'
  depends_on 'boost'
  depends_on 'libxml2'

  # polymake does not compile with XCode supplied in OSX >= 10.7,
  # so require compilation with apple-gcc42
  if MacOS.version >= :lion
      depends_on 'homebrew/dupes/apple-gcc42'
  end

  depends_on :x11

  fails_with :clang do
      build 425
      cause "segfault during build"
  end

  fails_with :llvm do
      build 2336
      cause "segfault during build"
  end

  def install
    ohai "Compilation takes a long time (~1 hour); use `brew install -v polymake` to see progress" unless ARGV.verbose?

    # Help configure find libraries
    readline = Formula.factory 'readline'
    gmp = Formula.factory 'gmp'
    mpfr = Formula.factory 'mpfr'
    boost = Formula.factory 'boost'
    libxml2 = Formula.factory 'libxml2'
    apple_gcc42 = Formula.factory 'homebrew/dupes/apple-gcc42'

    args = ["--with-fink=no",
            "--with-readline=#{readline.prefix}",
            "--with-gmp=#{gmp.prefix}",
            "--with-mpfr=#{mpfr.prefix}",
            "--with-boost=#{boost.prefix}",
            "--with-libxml2=#{libxml2.prefix}",
            "--docdir=#{doc}",
            "--prefix=#{prefix}"]

    # Force compilation with gcc4.2 for OSX 10.7 and greater
    if MacOS.version >= :lion then
        ENV['CC'] = "#{apple_gcc42.bin}/gcc-4.2"
        ENV['CXX'] = "#{apple_gcc42.bin}/g++-4.2"
    end

    args << "--without-java" unless build.include? "with-java"
    if build.include? "with-java" then
        # Current Oracle JDKs put jni.h in a different place than the original
        # Apple/Sun JDK.
        ENV['JAVA_HOME'] = `/usr/libexec/java_home`.chomp!
        if File.exist? "#{ENV['JAVA_HOME']}/include/jni.h" then
            ENV['JNI_HEADERS'] = "#{ENV['JAVA_HOME']}/include"
        elsif File.exist? "/System/Library/Frameworks/JavaVM.framework/Versions/Current/Headers/jni.h"
            ENV['JNI_HEADERS'] = "/System/Library/Frameworks/JavaVM.framework/Versions/Current/Headers"
        end
        args << "--with-java=#{ENV['JAVA_HOME']}"
        args << "--with-jni-headers=#{ENV['JNI_HEADERS']}"
    end

    args << "--without-javaview" unless build.include? "with-javaview"
    if build.include? "with-javaview" then
        # Copy javaview into share/ directory
        # NOTE: javaview is fully functional but requires
        # a free license for regular use.
        # http://www.javaview.de/download/registration.html
        ENV['JAVAVIEW'] = "#{share}/javaview/"
        mkdir_p ENV['JAVAVIEW']
        Javaview.new.brew { cp_r Dir['*'], ENV['JAVAVIEW'] }
        args << "--with-javaview=#{ENV['JAVAVIEW']}"
    end

    # Build 32-bit where appropriate, and help configure find 64-bit CPUs
    # NOTE: 32-bit build is untested.
    if MacOS.prefer_64_bit? and not build.build_32_bit?
        ENV.m64
        ENV['ARCHFLAGS'] = "-arch x86_64"
        args << "--build=x86_64"
    else
        ENV.m32
        ENV['ARCHFLAGS'] = "-arch i386"
        args << "--build=i386"
    end

    system "./configure", *args
    system "make install"
    system "make docs"
  end

  def caveats; <<-EOS.undent
      polymake requires the perl module Term::ReadLine::Gnu linked against the GNU readline library, supplied by Homebrew. See: https://coderwall.com/p/kk0hqw

          brew install readline
          cpan Term::ReadLine && cpan 
          look Term::ReadLine::Gnu
          perl Makefile.PL --includedir=$(brew info readline|egrep '[[:digit:]]+ files,'|awk '{print $1}')/include/ --libdir=$(brew info readline|egrep '[[:digit:]]+ files,'|awk '{print $1}')/lib/
          make && sudo make install

      If installing with javaview, remember to register for a license:
      http://www.javaview.de/download/registration.html
      EOS
  end

  def test
    system "polymake --version"
  end
end
