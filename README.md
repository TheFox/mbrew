# MusicBrew

MusicBrew is a combination of Spotify and [Homebrew](http://brew.sh/). Like a [package manager](https://en.wikipedia.org/wiki/Package_manager) for software but for music. It's made to use it via [comand-line](https://en.wikipedia.org/wiki/Command-line_interface). You can install all songs by a specified band, for example from ABBA via `music install ABBA`. The .mp3 files will be downloaded from a central server to your local music collection. The search acts like on a traditional package manager, for example via `music search AC/DC`. Like on Homebrew, each song file gets a *formula*/meta file. These files will be searched locally when the search command is used. On `music update` all meta files will be updated through Git. The `music upgrade` command is used to upgrade all existing artists. New songs will be downloaded. Since it's not legal in most of the countries on earth to copy and distribute copyright protected music it's highly recommended to encrypt the .mp3 files. This will be done with the best encryption software ever been made: [GnuPG](https://gnupg.org/). Beside the aspect of the copyright there is also the aspect to encrypt your files when using blanc HTTP (instead of HTTPS).

## Documentation

For all kinds of documentation see [`mbrew(1)`](http://mbrew.fox21.at/).

## License
Copyright (C) 2015 Christian Mayer <http://fox21.at>

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
