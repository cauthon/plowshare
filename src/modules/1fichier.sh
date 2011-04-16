#!/bin/bash
#
# 1fichier.com module
# Copyright (c) 2011 halfman <Pulpan3@gmail.com>
#
# This file is part of Plowshare.
#
# Plowshare is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Plowshare is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Plowshare.  If not, see <http://www.gnu.org/licenses/>.

MODULE_1FICHIER_REGEXP_URL="http://\(.*\.\)\?\(1fichier\.\(com\|net\|org\|fr\)\|alterupload\.com\|cjoint\.\(net\|org\)\|desfichiers\.\(com\|net\|org\|fr\)\|dfichiers\.\(com\|net\|org\|fr\)\|megadl\.fr\|mesfichiers\.\(net\|org\)\|piecejointe\.\(net\|org\)\|pjointe\.\(com\|net\|org\|fr\)\|tenvoi\.\(com\|net\|org\)\|dl4free\.com\)/"
MODULE_1FICHIER_DOWNLOAD_OPTIONS=""
MODULE_1FICHIER_UPLOAD_OPTIONS="
AUTH,a:,auth:,USER:PASSWORD,Use an account
LINK_PASSWORD,p:,link-password:,PASSWORD,Protect a link with a password
MESSAGE,d:,message:,MESSAGE,Set file message (is send with notification email)
DOMAIN,,domain:,ID,You can set domain ID to upload (ID can be found at http://www.1fichier.com/en/api/web.html)
EMAIL,,email:,EMAIL,Field for notification email"
MODULE_1FICHIER_DOWNLOAD_CONTINUE=yes

# Output a 1fichier file download URL
# $1: 1FICHIER_URL
# stdout: real file download link
1fichier_download() {
    set -e
    eval "$(process_options 1fichier "$MODULE_1FICHIER_DOWNLOAD_OPTIONS" "$@")"

    URL=$1
    COOKIES=$(create_tempfile)

    PAGE=$(curl -c "$COOKIES" "$URL")

    if match "Le fichier demandé n'existe pas." "$PAGE"; then
        log_error "File not found."
        rm -f $COOKIES
        return 254
    fi

    test "$CHECK_LINK" && return 255

    FILE_URL=$(echo "$PAGE" | parse_attr 'Cliquez ici pour' 'href')
    FILENAME=$(echo "$PAGE" | parse_quiet '<title>' '<title>Téléchargement du fichier : *\([^<]*\)')

    echo "$FILE_URL"
    test "$FILENAME" && echo "$FILENAME"
    echo "$COOKIES"

    return 0
}

1fichier_upload() {
    set -e
    eval "$(process_options 1fichier "$MODULE_1FICHIER_UPLOAD_OPTIONS" "$@")"
    
    local FILE=$1
    local DESTFILE=${2:-$FILE}
    local UPLOADURL="http://upload.1fichier.com"
    
    COOKIES=$(create_tempfile)
    
    if test "$AUTH"; then
        LOGIN_DATA='mail=$USER&pass=$PASSWORD&submit=Login'
        post_login "$AUTH" "$COOKIES" "$LOGIN_DATA" "https://www.1fichier.com/en/login.pl" >/dev/null || {
            rm -f $COOKIES
            return 1
        }
    fi
    
    S_ID=$(echo "var text = ''; var possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'; for( var i=0; i < 5; i++ ) text += possible.charAt(Math.floor(Math.random() * possible.length)); print(text);" | javascript)
    
    ! test "$DOMAIN" && DOMAIN=0
    
    STATUS=$(curl_with_log -b "$COOKIES" \
        -F "message=$MESSAGE" \
        -F "mail=$EMAIL" \
        -F "dpass=$LINK_PASSWORD" \
        -F "domain=$DOMAIN" \
        -F "file[]=@$FILE;filename=$(basename_file "$DESTFILE")" \
        "$UPLOADURL/upload.cgi?id=$S_ID")
    
    rm -f $COOKIES
    
    RESPONSE=$(curl --header "EXPORT:1" "$UPLOADURL/end.pl?xid=$S_ID" | sed -e 's/;/\n/g')
    
    DOWNLOAD_ID=$(echo "$RESPONSE" | sed -n '3p')
    
    REMOVE_ID=$(echo "$RESPONSE" | sed -n '4p')
    
    DOMAIN_ID=$(echo "$RESPONSE" | sed -n '5p')
    
    case "$DOMAIN_ID" in
        0)
            echo -e "http://$DOWNLOAD_ID.1fichier.com (.net, .org, .fr)\n(delete: http://www.1fichier.com/remove/$DOWNLOAD_ID/$REMOVE_ID)"
            ;;
         
        1)
            echo -e "http://$DOWNLOAD_ID.alterupload.com\n(delete: http://www.alterupload.com/remove/$DOWNLOAD_ID/$REMOVE_ID)"
            ;;
         
        2)
            echo -e "http://$DOWNLOAD_ID.cjoint.net (.org)\n(delete: http://www.cjoint.net/remove/$DOWNLOAD_ID/$REMOVE_ID)"
            ;;
        3)
            echo -e "http://$DOWNLOAD_ID.desfichiers.com (.net, .org, .fr)\n(delete: http://www.desfichiers.com/remove/$DOWNLOAD_ID/$REMOVE_ID)"
            ;;
        4)
            echo -e "http://$DOWNLOAD_ID.dfichiers.com (.net, .org, .fr)\n(delete: http://www.dfichiers.com/remove/$DOWNLOAD_ID/$REMOVE_ID)"
            ;;
        5)
            echo -e "http://$DOWNLOAD_ID.megadl.fr\n(delete: http://www.megadl.fr/remove/$DOWNLOAD_ID/$REMOVE_ID)"
            ;;
        6)
            echo -e "http://$DOWNLOAD_ID.mesfichiers.net (.org)\n(delete: http://www.mesfichiers.net/remove/$DOWNLOAD_ID/$REMOVE_ID)"
            ;;
        7)
            echo -e "http://$DOWNLOAD_ID.piecejointe.net (.org)\n(delete: http://www.piecejointe.net/remove/$DOWNLOAD_ID/$REMOVE_ID)"
            ;;
        8)
            echo -e "http://$DOWNLOAD_ID.pjointe.com (.net, .org, .fr)\n(delete: http://www.pjointe.com/remove/$DOWNLOAD_ID/$REMOVE_ID)"
            ;;
        9)
            echo -e "http://$DOWNLOAD_ID.tenvoi.com (.net, .org)\n(delete: http://www.tenvoi.com/remove/$DOWNLOAD_ID/$REMOVE_ID)"
            ;;
        10)
            echo -e "http://$DOWNLOAD_ID.dl4free.com\n(delete: http://www.dl4free.com/remove/$DOWNLOAD_ID/$REMOVE_ID)"
            ;;
        *)
            log_error "Bad domain ID response, maybe API updated?"
            exit 1
    esac
    
    exit 0
}