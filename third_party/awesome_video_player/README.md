# Awesome Video Player
[awesome_video_player](https://pub.dev/packages/awesome_video_player) A powerful, actively maintained Flutter video player built for the modern developer.

[![pub package](https://img.shields.io/pub/v/awesome_video_player.svg)](https://pub.dartlang.org/packages/awesome_video_player)
[![pub package](https://img.shields.io/github/license/jhomlala/betterplayer.svg?style=flat)](https://github.com/jhomlala/betterplayer)
[![pub package](https://img.shields.io/badge/platform-flutter-blue.svg)](https://github.com/nateshmbhat/awesome_video_player)

## Why Awesome Video Player?
Looking for a reliable, feature-rich video player that won't be abandoned? You're in the right place! Awesome Video Player is an actively maintained fork of the better_player ecosystem, enhanced with modern features, critical bug fixes, and regular updates.

**Features:**  
- 📝 Playlist support
- 📱 Video in ListView support
- 💬 Subtitles support: (formats: SRT, WEBVTT with HTML tags support; subtitles from HLS; multiple subtitles for video)
- 🔒 DRM support (token, Widevine, FairPlay EZDRM)
- 📡 HTTP Headers support
- 🖼️ BoxFit of video support
- ⚡ Playback speed support
- 🔄 Alternative resolution support
- 🎥 HLS support (track, subtitles (also segmented), audio track selection)
- 📺 DASH support (track, subtitles, audio track selection)
- ⚙️ Added advanced configuration options
- 🎮 Refactored player controls
- 💾 Cache support
- 🔔 Notifications support
- 📍 Picture in Picture support
- 🐛 Bug Fixes
- ✨ ... and much more!


### Not Just Another Video Player
While other video player libraries come and go, Awesome Video Player is here to stay. Here's how we stand out:

| Feature                                   | Awesome Video Player | video_player | chewie  | better_player | better_player_plus |
|-------------------------------------------|----------------------|-------------|---------|---------------|--------------------|
| Active Maintenance                        | ✅                   | ✅          | ✅       | ❌            | ❌                 |
| DRM (Widevine, FairPlay)                  | ✅                   | ❌          | ❌       | ✅            | ✅                 |
| DASH Streaming                            | ✅                   | ❌          | ❌       | ✅            | ✅                 |
| HLS Streaming                             | ✅                   | Limited     | Limited  | ✅            | ✅                 |
| HLS Default Audio Stream Selection         | ✅                   | ❌          | ❌       | ❌            | ❌                 |
| Audio Track Switching                     | ✅                   | ❌          | ❌       | ✅            | ✅                 |
| Multi-Format Subtitles (SRT, WEBVTT, HLS) | ✅                   | ❌          | Limited  | ✅            | ✅                 |
| HTML Tags in Subtitles                    | ✅                   | ❌          | ❌       | ✅            | ✅                 |
| Subtitle Style Customization              | ✅                   | ❌          | ❌       | ✅            | ✅                 |
| Alternative Resolution Switching          | ✅                   | ❌          | ❌       | ✅            | ✅                 |
| Picture in Picture                        | ✅                   | ❌          | ❌       | ❌            | ✅                 |
| Playlist Support                          | ✅                   | ❌          | ❌       | ✅            | ✅                 |
| Video Caching                             | ✅                   | ❌          | ❌       | ✅            | ✅                 |
| Custom Controls Configuration             | ✅                   | ❌          | Limited  | ✅            | ✅                 |
| Advanced Error Handling                   | ✅                   | Limited     | Limited  | ✅            | ✅                 |
| Custom HTTP Headers                       | ✅                   | ✅          | ✅       | ✅            | ✅                 |
| Recent Bug Fixes                          | ✅                   | ✅          | ✅       | ❌            | ❌                 |


---

### Our Commitment
- 🔧 Actively Maintained: Regular updates, bug fixes, and feature improvements
- 🚀 Performance First: Built on modern Media3 ExoPlayer
- 💪 Battle-tested: Based on the robust better_player foundation
- 👥 Community Driven: Your issues and PRs are welcome and valued
- 📚 Well Documented: Comprehensive guides and examples



### Notable Improvements Over Predecessor Libraries

**🎯 Correct HLS Default Audio Selection:** Properly respects the DEFAULT flag in HLS manifests for audio track selection, fixing a long-standing issue in better_player and better_player_plus where the first stream was always selected regardless of the default flag.


## Documentation
* [Official documentation](https://jhomlala.github.io/betterplayer/)
* [Example application](https://github.com/nateshmbhat/awesome_video_player/tree/master/example)
* [API reference](https://pub.dev/documentation/awesome_video_player/latest/awesome_video_player/awesome_video_player-library.html)




### Some usecase screenshots

<table>
   <tr>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/1.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/2.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/3.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/4.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/5.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/6.png">
      </td>
   </tr>
   <tr>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/7.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/8.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/9.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/10.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/11.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/12.png">
      </td>
   </tr>
   <tr>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/13.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/14.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/15.png">
      </td>
      <td>
         <img width="250px" src="https://raw.githubusercontent.com/jhomlala/betterplayer/master/media/16.png">
      </td>
    </tr>	
</table>


# Contributing
Your contributions make Awesome Video Player better! Whether it's:

- 🐛 Bug reports
- 💡 Feature suggestions
- 🛠️ Pull requests
- 📚 Documentation improvements

All contributions are welcome! Let's make this the best video player for Flutter together.
Support
Need help? Found a bug? Have a feature request?
- 📩 Open an issue
- ⭐ Star the repo to show your support!

