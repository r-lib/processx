#ifndef _PtyProcess_WinPtyBackend_h_
#define _PtyProcess_WinPtyBackend_h_

// Upp-libwinpty header files.

#if (defined(flagWIN32) || defined(flagWIN64)) && !defined(flagWIN10)
	#define  UNICODE
	#define  COMPILING_WINPTY_STATIC
//  #define  AGENT_EXE L"PtyAgent.exe"
	#include "include/winpty.h"
	#include "libwinpty/AgentLocation.h"
	#include "shared/AgentMsg.h"
	#include "shared/BackgroundDesktop.h"
	#include "shared/Buffer.h"
	#include "shared/DebugClient.h"
	#include "shared/GenRandom.h"
	#include "shared/OsModule.h"
	#include "shared/OwnedHandle.h"
	#include "shared/StringBuilder.h"
	#include "shared/StringUtil.h"
	#include "shared/WindowsSecurity.h"
	#include "shared/WindowsVersion.h"
	#include "shared/WinptyAssert.h"
	#include "shared/WinptyException.h"
	#include "shared/WinptyVersion.h"
	#include "shared/winpty_snprintf.h"
#endif

#endif
