/////////////////////////////////////////////////////////////////////////////
// Name:        src/osx/cocoa/utils_base.mm
// Purpose:     various OS X utility functions in the base lib
//              (extracted from cocoa/utils.mm)
// Author:      Tobias Taschner
// Created:     2016-02-10
// Copyright:   (c) wxWidgets development team
// Licence:     wxWindows licence
/////////////////////////////////////////////////////////////////////////////

#include "wx/wxprec.h"

#include "wx/utils.h"
#include "wx/platinfo.h"

#ifndef WX_PRECOMP
    #include "wx/intl.h"
    #include "wx/app.h"
    #include "wx/datetime.h"
#endif
#include "wx/filename.h"
#include "wx/apptrait.h"

#include "wx/osx/private.h"

#if (defined(__WXOSX_COCOA__) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_10) \
    || (defined(__WXOSX_IPHONE__) && defined(__IPHONE_8_0))
    #define wxHAS_NSPROCESSINFO 1
#endif

// our OS version is the same in non GUI and GUI cases
wxOperatingSystemId wxGetOsVersion(int *verMaj, int *verMin, int *verMicro)
{
#ifdef wxHAS_NSPROCESSINFO
    // Note: we don't use WX_IS_MACOS_AVAILABLE() here because these properties
    // are only officially supported since 10.10, but are actually available
    // under 10.9 too, so we prefer to check for them explicitly and suppress
    // the warnings that using without a __builtin_available() check around
    // them generates.
    wxCLANG_WARNING_SUPPRESS(unguarded-availability)

    if ([NSProcessInfo instancesRespondToSelector:@selector(operatingSystemVersion)])
    {
        NSOperatingSystemVersion osVer = [NSProcessInfo processInfo].operatingSystemVersion;

        if ( verMaj != NULL )
            *verMaj = osVer.majorVersion;

        if ( verMin != NULL )
            *verMin = osVer.minorVersion;

        if ( verMicro != NULL )
            *verMicro = osVer.patchVersion;
    }

    wxCLANG_WARNING_RESTORE(unguarded-availability)

    else
#endif
    {
        // On OS X versions prior to 10.10 NSProcessInfo does not provide the OS version
        // Deprecated Gestalt calls are required instead
wxGCC_WARNING_SUPPRESS(deprecated-declarations)
        SInt32 maj, min, micro;
#ifdef __WXOSX_IPHONE__
        maj = 7;
        min = 0;
        micro = 0;
#else
        Gestalt(gestaltSystemVersionMajor, &maj);
        Gestalt(gestaltSystemVersionMinor, &min);
        Gestalt(gestaltSystemVersionBugFix, &micro);
#endif
wxGCC_WARNING_RESTORE()

        if ( verMaj != NULL )
            *verMaj = maj;

        if ( verMin != NULL )
            *verMin = min;

        if ( verMicro != NULL )
            *verMicro = micro;
    }

    return wxOS_MAC_OSX_DARWIN;
}

bool wxCheckOsVersion(int majorVsn, int minorVsn, int microVsn)
{
#ifdef wxHAS_NSPROCESSINFO
    // As above, this API is effectively available earlier than its
    // availability attribute indicates, so check for it manually.
    wxCLANG_WARNING_SUPPRESS(unguarded-availability)

    if ([NSProcessInfo instancesRespondToSelector:@selector(isOperatingSystemAtLeastVersion:)])
    {
        NSOperatingSystemVersion osVer;
        osVer.majorVersion = majorVsn;
        osVer.minorVersion = minorVsn;
        osVer.patchVersion = microVsn;

        return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:osVer] != NO;
    }

    wxCLANG_WARNING_RESTORE(unguarded-availability)

    else
#endif
    {
        int majorCur, minorCur, microCur;
        wxGetOsVersion(&majorCur, &minorCur, &microCur);

        return majorCur > majorVsn
            || (majorCur == majorVsn && minorCur >= minorVsn)
            || (majorCur == majorVsn && minorCur == minorVsn && microCur >= microVsn);
    }
}

wxString wxGetOsDescription()
{

    int majorVer, minorVer;
    wxGetOsVersion(&majorVer, &minorVer);

#ifndef __WXOSX_IPHONE__
    // Notice that neither the OS name itself nor the code names seem to be
    // ever translated, OS X itself uses the English words even for the
    // languages not using Roman alphabet.
    // Starting with 10.12 the macOS branding is used
    wxString osBrand = wxCheckOsVersion(10, 12) ? "macOS" : "OS X";
    wxString osName;
    if (majorVer == 10)
    {
        switch (minorVer)
        {
            case 7:
                osName = "Lion";
                // 10.7 was the last version where the "Mac" prefix was used
                osBrand = "Mac OS X";
                break;
            case 8:
                osName = "Mountain Lion";
                break;
            case 9:
                osName = "Mavericks";
                break;
            case 10:
                osName = "Yosemite";
                break;
            case 11:
                osName = "El Capitan";
                break;
            case 12:
                osName = "Sierra";
                break;
            case 13:
                osName = "High Sierra";
                break;
            case 14:
                osName = "Mojave";
                break;
        };
    }
#else
    wxString osBrand = "iOS";
    wxString osName;
#endif

    wxString osDesc = osBrand;
    if (!osName.empty())
        osDesc += " " + osName;

    NSString* osVersionString = [NSProcessInfo processInfo].operatingSystemVersionString;
    if (osVersionString)
        osDesc += " " + wxCFStringRef::AsString((CFStringRef)osVersionString);

    return osDesc;
}

/* static */
#if wxUSE_DATETIME
bool wxDateTime::GetFirstWeekDay(wxDateTime::WeekDay *firstDay)
{
    wxCHECK_MSG( firstDay, false, wxS("output parameter must be non-null") );

    NSCalendar *calendar = [NSCalendar currentCalendar];
    [calendar setLocale:[NSLocale autoupdatingCurrentLocale]];

    *firstDay = wxDateTime::WeekDay(([calendar firstWeekday] - 1) % 7);
    return true;
}
#endif // wxUSE_DATETIME

bool wxCocoaLaunch(const char* const* argv, pid_t &pid)
{
    // Obtains the number of arguments for determining the size of
    // the CFArray used to hold them
    NSUInteger cfiCount = 0;
    for (const char* const* argvcopy = argv; *argvcopy != NULL; ++argvcopy)
    {
        ++cfiCount;
    }
    
    // If there is not a single argument then there is no application
    // to launch
    if(cfiCount == 0)
    {
        wxLogDebug(wxT("wxCocoaLaunch No file to launch!"));
        return false ;
    }
    
    // Path to bundle
    wxString path = *argv++;
    NSError *error = nil;
    NSURL *url = [NSURL fileURLWithPath:wxCFStringRef(path).AsNSString() isDirectory:YES];
    
    // Check the URL validity
    if( url == nil )
    {
        wxLogDebug(wxT("wxCocoaLaunch Can't open path: %s"), path.c_str());
        return false ;
    }
    
    // Loop through command line arguments to the bundle,
    // turn them into CFURLs and then put them in cfaFiles
    // For use to launch services call
    NSMutableArray *params = [[NSMutableArray alloc] init];
    for( ; *argv != NULL; ++argv )
    {
        // Check for '<' as this will ring true for
        // CFURLCreateWithString but is generally not considered
        // typical on mac but is usually passed here from wxExecute
        if (wxStrcmp(*argv, wxT("<")) == 0)
            continue;

        NSURL *cfurlCurrentFile;
        wxFileName argfn(*argv);     // Filename for path
        wxString dir( *argv );
        if(argfn.DirExists())
        {
            // First, try creating as a directory
            cfurlCurrentFile = [NSURL fileURLWithPath:wxCFStringRef(dir).AsNSString() isDirectory:YES];
        }
        else if(argfn.FileExists())
        {
            // And if it isn't a directory try creating it
            // as a regular file
            cfurlCurrentFile = [NSURL fileURLWithPath:wxCFStringRef(dir).AsNSString() isDirectory:NO];
        }
        else
        {
            // Argument did not refer to
            // an entry in the local filesystem,
            // so try creating it through CFURLCreateWithString
            cfurlCurrentFile = [NSURL URLWithString:wxCFStringRef(dir).AsNSString()];
        }

        // Continue in the loop if the CFURL could not be created
        if(cfurlCurrentFile == nil)
        {
            wxLogDebug(
                       wxT("wxCocoaLaunch Could not create NSURL for argument:%s"),
                       *argv);
            continue;
        }
        
        // Add the valid CFURL to the argument array and then
        // release it as the CFArray adds a ref count to it
        [params addObject:cfurlCurrentFile];
    }
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSRunningApplication *app = [ws launchApplicationAtURL:url options:NSWorkspaceLaunchAsync
                                             configuration:[NSDictionary dictionaryWithObject:params forKey:NSWorkspaceLaunchConfigurationArguments]
                                             error:&error];
    if( app != nil )
        pid = [app processIdentifier];
    else
    {
        wxString errorDesc = wxCFStringRef::AsString([error localizedDescription]);
        wxLogDebug( wxString::Format( "wxCocoaLaunch failure: error is %s", errorDesc ) );
        return false;
    }
    return true;
}
