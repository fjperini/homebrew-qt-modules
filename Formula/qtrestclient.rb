class Qtrestclient < Formula
	version "2.0.0"
	revision 1
	desc "A library for generic JSON-based REST-APIs, with a mechanism to map JSON to Qt objects"
	homepage "https://github.com/Skycoder42/QtRestClient/"
	url "https://github.com/Skycoder42/QtRestClient/archive/#{version}.tar.gz"
	sha256 "e604a7936fd19f8b5f62aa50ab48f93fc1ec7f10fc725e60f2c14e96e0ef7009"
	
	keg_only "Qt itself is keg only which implies the same for Qt modules"
	
	option "with-docs", "Build documentation"
	
	depends_on "qt"
	depends_on "qtjsonserializer"
	depends_on :xcode => :build
	depends_on "python3" => [:build, "with-docs"]
	depends_on "doxygen" => [:build, "with-docs"]
	depends_on "graphviz" => [:build, "with-docs"]
	
	def file_replace(file, base, suffix)
		text = File.read(file)
		replace = text.gsub(base, "#{base}/../../../qtrestclient/#{pkg_version}/#{suffix}")
		File.open(file, "w") { |f| f << replace }
	end
	
	def install
		Dir.mkdir ".git"
		Dir.mkdir "build"
		Dir.chdir "build"
		
		ENV["QMAKEPATH"] = "#{ENV["QMAKEPATH"]}:#{HOMEBREW_PREFIX}/Cellar/qtjsonserializer/#{Formula["qtjsonserializer"].pkg_version}"
		system "qmake", "-config", "release", ".."
		system "make", "qmake_all"
		system "make"
		
		if build.with? "docs"
			system "make", "doxygen"
		end
		
		# ENV.deparallelize
		instdir = "#{buildpath}/install"
		system "make", "INSTALL_ROOT=#{instdir}", "install"
		prefix.install Dir["#{instdir}#{HOMEBREW_PREFIX}/Cellar/qt/#{Formula["qt"].pkg_version}/*"]
		
		# overwrite pri include
		file_replace "#{prefix}/mkspecs/modules/qt_lib_restclient.pri", "QT_MODULE_LIB_BASE", "lib"
		file_replace "#{prefix}/mkspecs/modules/qt_lib_restclient.pri", "QT_MODULE_BIN_BASE", "bin"
		file_replace "#{prefix}/mkspecs/modules/qt_lib_restclient_private.pri", "QT_MODULE_LIB_BASE", "lib"
		
		#create bash src
		File.open("#{prefix}/bashrc.sh", "w") { |file| file << "export QMAKEPATH=$QMAKEPATH:#{prefix}" }
	end
	
	test do
		(testpath/"test.pro").write <<~EOS
		CONFIG -= app_bundle
		QT += restclient
		SOURCES += main.cpp
		EOS
		
		(testpath/"main.cpp").write <<~EOS
		#include <QtCore>
		#include <QtRestClient>
		int main() {
			QtRestClient::RestClient r;
			qDebug() << r.serializer();
			return 0;
		}
		EOS
		
		ENV["QMAKEPATH"] = "#{ENV["QMAKEPATH"]}:#{prefix}:#{HOMEBREW_PREFIX}/Cellar/qtjsonserializer/#{Formula["qtjsonserializer"].pkg_version}"
		system "#{Formula["qt"].bin}/qmake", "test.pro"
		system "make"
		system "./test"
	end
end
