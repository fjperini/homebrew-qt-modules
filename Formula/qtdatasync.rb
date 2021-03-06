class Qtdatasync < Formula
	version "4.1.0"
	revision 1
	desc "A simple offline-first synchronisation framework, to synchronize data of Qt applications between devices"
	homepage "https://github.com/Skycoder42/QtDataSync"
	url "https://github.com/Skycoder42/QtDataSync/archive/#{version}.tar.gz"
	sha256 "289abfdda693430b46b4f0a1fb8fe00ceaa97d8baccd7518a2626b22329bebd2"
	
	keg_only "Qt itself is keg only which implies the same for Qt modules"
	
	option "with-docs", "Build documentation"
	
	depends_on "qt"
	depends_on "qtjsonserializer"
	depends_on "qtservice"
	depends_on "cryptopp"
	depends_on :xcode => :build
	depends_on "pkg-config" => :build
	depends_on "qpmx" => :build
	depends_on "qpm" => :build
	depends_on "python3" => [:build, "with-docs"]
	depends_on "doxygen" => [:build, "with-docs"]
	depends_on "graphviz" => [:build, "with-docs"]
	
	def file_replace(file, base, suffix)
		text = File.read(file)
		replace = text.gsub(base, "#{base}/../../../qtdatasync/#{pkg_version}/#{suffix}")
		File.open(file, "w") { |f| f << replace }
	end
	
	def install
		# mangle in cryptopp
		FileUtils.ln_s "#{HOMEBREW_PREFIX}/Cellar/cryptopp/#{Formula["cryptopp"].pkg_version}/lib", "src/3rdparty/cryptopp/lib"
		FileUtils.ln_s "#{HOMEBREW_PREFIX}/Cellar/cryptopp/#{Formula["cryptopp"].pkg_version}/include", "src/3rdparty/cryptopp/include"
		# fix keychain config
		File.open("src/plugins/keystores/keystores.pro", "r") do |orig|
			File.unlink("src/plugins/keystores/keystores.pro")
			File.open("src/plugins/keystores/keystores.pro", "w") do |new|
				new.write "keychain.CONFIG += no_lrelease_target\n"
				new.write(orig.read())
			end
		end
		
		Dir.mkdir ".git"
		Dir.mkdir "build"
		Dir.chdir "build"
		
		ENV["QMAKEPATH"] = "#{ENV["QMAKEPATH"]}:#{HOMEBREW_PREFIX}/Cellar/qtjsonserializer/#{Formula["qtjsonserializer"].pkg_version}"
		ENV["QMAKEPATH"] = "#{ENV["QMAKEPATH"]}:#{HOMEBREW_PREFIX}/Cellar/qtservice/#{Formula["qtservice"].pkg_version}"
		ENV["QPMX_CACHE_DIR"] = "#{ENV["HOME"]}/qpmx-cache"
		system "mkdir", "-p", "#{ENV["QPMX_CACHE_DIR"]}"
		system "qmake", "-config", "release", ".."
		system "make", "qmake_all"
		system "make"
		system "make", "lrelease"
		
		if build.with? "docs"
			system "make", "doxygen"
		end
		
		# ENV.deparallelize
		instdir = "#{buildpath}/install"
		system "make", "INSTALL_ROOT=#{instdir}", "install"
		prefix.install Dir["#{instdir}#{HOMEBREW_PREFIX}/Cellar/qt/#{Formula["qt"].pkg_version}/*"]
		
		# overwrite pri include
		file_replace "#{prefix}/mkspecs/modules/qt_lib_datasync.pri", "QT_MODULE_LIB_BASE", "lib"
		file_replace "#{prefix}/mkspecs/modules/qt_lib_datasync.pri", "QT_MODULE_BIN_BASE", "bin"
		file_replace "#{prefix}/mkspecs/modules/qt_lib_datasync_private.pri", "QT_MODULE_LIB_BASE", "lib"
		
		#create bash src
		File.open("#{prefix}/bashrc.sh", "w") { |file|
			file << "export QMAKEPATH=$QMAKEPATH:#{prefix}"
			file << ""
			file << "echo WARNING: In order to find the keystore plugins, you must export PLUGIN_KEYSTORES_PATH before running an application built against datasync"
		}
	end
	
	test do
		(testpath/"test.pro").write <<~EOS
			CONFIG -= app_bundle
			CONFIG += c++14
			QT += datasync
			SOURCES += main.cpp
		EOS
		
		(testpath/"main.cpp").write <<~EOS
			#include <QtCore>
			#include <QtDataSync>
			int main() {
				QtDataSync::Setup s;
				return 0;
			}
		EOS
		
		ENV["QMAKEPATH"] = "#{ENV["QMAKEPATH"]}:#{prefix}"
		ENV["QMAKEPATH"] = "#{ENV["QMAKEPATH"]}:#{HOMEBREW_PREFIX}/Cellar/qtjsonserializer/#{Formula["qtjsonserializer"].pkg_version}"
		ENV["QMAKEPATH"] = "#{ENV["QMAKEPATH"]}:#{HOMEBREW_PREFIX}/Cellar/qtservice/#{Formula["qtservice"].pkg_version}"
		system "#{Formula["qt"].bin}/qmake", "test.pro"
		system "make"
		system "./test"
	end
end
