#winewrap
**Author**: Markus Kitsinger <root@swooshalicio.us>  
**Original author**: Juraj Puchký - Devtech <sjurajpuchky@seznam.cz>  
**Version**: 1.1.0
**License**: GPLv3

##Description
winewrap is a fork of sjurajpuchky's wrappit4wine.  
It consists of two scripts, winewrap-dll and winewrap-so. These scripts generate files useful when creating wine wrappers for native libraries. winewrap-dll generates files using a windows dynamic link library, and winewrap-so generates files using a native library.

You can run the scripts with "--help" or see the man pages for usage information.

##License
> winewrap is free software: you can redistribute it and/or modify  
 it under the terms of the GNU General Public License as published by  
 the Free Software Foundation, either version 3 of the License, or  
 (at your option) any later version.

> winewrap is distributed in the hope that it will be useful,  
 but WITHOUT ANY WARRANTY; without even the implied warranty of  
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the  
 GNU General Public License for more details.

> You should have received a copy of the GNU General Public License  
 along with winewrap.  If not, see <http://www.gnu.org/licenses/>.

##Changelog
**1.1.0**: winewrap is now a full on fork of wrappit4wine rather than just a "modified version".  
> * wrappit4wine script renamed to winewrap-dll
* new winewrap-so script for generation without the use of a windows library
* new format for arguments
 * prefix now optional
 * no more dependence on environment variables to pass in information
 * no more options set by variables in the scripts
 * you can now specify multiple library and includes search directories
* various miscellaneous fixes

**1.0.1+ors1**: First version of the winewrap version of wrappit4wine
> * switched to perl regex for grabbing prototypes
* overhauled source generation
* fixed expr commands
* switched to a more detailed dialog for progress information
* progress information in more places

**1.0.1**: Base version of wrappit4wine used for winewrap
> * Fixed generating of spec
