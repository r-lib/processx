#include "libwinpty.h"

// Upp-libwinpty source files.

#if (defined(flagWIN32) || defined(flagWIN64)) && !defined(flagWIN10)
	#include "libwinpty/winpty.cc"
	#include "libwinpty/AgentLocation.cc"
	#include "shared/BackgroundDesktop.cc"
	#include "shared/Buffer.cc"
	#include "shared/DebugClient.cc"
	#include "shared/GenRandom.cc"
	#include "shared/OwnedHandle.cc"
	#include "shared/StringUtil.cc"
	#include "shared/WindowsSecurity.cc"
	#include "shared/WindowsVersion.cc"
	#include "shared/WinptyAssert.cc"
	#include "shared/WinptyException.cc"
	#include "shared/WinptyVersion.cc"
#endif
