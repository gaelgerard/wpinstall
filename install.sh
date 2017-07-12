#!/bin/bash
#
# Automatize WordPress installation
# bash install.sh
# /d/WEB2013/WP_CLI/Scripts/dfwp/config.sh
#
# Inspirated from Maxime BJ
# For more information, please visit 
# http://www.wp-spread.com/tuto-wp-cli-comment-installer-et-configurer-wordpress-en-moins-dune-minute-et-en-seulement-un-clic/

#  ==============================
#  ECHO COLORS, FUNCTIONS AND VARS
#  ==============================
bggreen='\033[42m'
bgred='\033[41m'
bold='\033[1m'
black='\033[30m'
gray='\033[37m'
normal='\033[0m'

# Jump a line
function line {
	echo " "
}

# Basic echo
function bot {
	line
	echo -e "$1 ${normal}"
}

# Error echo
function error {
	line
	echo -e "${bgred}${bold}${gray} $1 ${normal}"
}

# Success echo
function success {
	line
	echo -e "${bggreen}${bold}${gray} $1 ${normal}"
}

#  ==============================
#  CONFIG
#  ==============================
read -p "Chemin du fichier de config (d:/WEB2013/WP_CLI/Scripts/dfwp/config.sh) : " config
if [ -z $config ]
	then
		error 'Renseigner un fichier de config'
		exit
fi

# Chargement du fichier de config
source $config

#  ==============================
#  VARS
#  ==============================

# DB
dbprefix="$prefix"

# Paths
pathtoinstall="${rootpath}${foldername}"

success "Récap"
echo "--------------------------------------"
echo -e "Root path                   : $rootpath"
echo -e "Path du projet              : $pathtoinstall"
echo -e "Url                         : $url"
echo -e "Langue iso                  : $wplang"
echo -e "Foldername                  : $foldername"
echo -e "Titre du projet             : $title"
echo -e "Nom base de données         : $dbname"
echo -e "Utilisateur base de données : $dbuser"
echo -e "Password base de données    : $dbpass"
echo -e "Prefix base de données      : $dbprefix"
echo -e "Login admin                 : $adminlogin"
echo -e "Pass admin                  : $adminpass"
echo -e "Email admin                 : $adminemail"


if [ -n "$pluginfilepath" ]
	then
		echo -e "Fichier qui liste les plugins à installer : $pluginfilepath"
fi
if [ -n "$acfkey" ]
	then
		echo -e "Clé ACF pro : $acfkey"
fi
echo -e "Liste des plugins à installer : $pluginfilepath"
echo "--------------------------------------"



#  ==============================
#  = The show is about to begin =
#  ==============================

# Welcome !
success "L'installation va pouvoir commencer"
echo "--------------------------------------"

# CHECK :  Directory doesn't exist
cd $rootpath

# Check if provided folder name already exists
if [ -d $pathtoinstall ]; then
  error "Le dossier $pathtoinstall existe déjà. Par sécurité, je ne vais pas plus loin pour ne rien écraser."
  exit 1
fi

# Create directory
bot "-> Je crée le dossier : $foldername"
mkdir $foldername
cd $foldername

bot "-> Je crée le fichier de configuration wp-cli.yml"
echo "
# Configuration de wpcli
# Voir http://wp-cli.org/config/

# Les modules apaches à charger
apache_modules:
	- mod_rewrite
" >> wp-cli.yml

# Download WP
bot "-> Je télécharge la dernière version de WordPress $wplang..."
wp core download --locale=$wplang --force

# Create base configuration
bot "-> Je lance la configuration de WP"
wp core config --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --dbprefix=$dbprefix --extra-php <<PHP
// Désactiver l'éditeur de thème et de plugins en administration
define('DISALLOW_FILE_EDIT', true);

// Changer le nombre de révisions de contenus
define('WP_POST_REVISIONS', 3);

// Supprimer automatiquement la corbeille tous les 7 jours
//define('EMPTY_TRASH_DAYS', 7);

//Mode debug
define('WP_DEBUG', true);
PHP

# Create database
bot "-> Je crée la base de données"
wp db create

# Launch install
bot "-> J'installe WordPress..."
wp core install --url=$url --title="$title" --admin_user=$adminlogin --admin_email=$adminemail --admin_password=$adminpass

# Si on a bien un fichier qui listes les plugins à installer
if [ -n "$pluginfilepath" ]
	then
	    # Plugins install
        bot "-> J'installe les plugins à partir de la liste"
        while read line || [ -n "$line" ]
        do
            bot "-> Plugin $line"
            wp plugin install $line --activate
        done < "$pluginfilepath"
fi

# Si on a bien une clé acf pro
if [ -n "$acfkey" ]
	then
		bot "-> J'installe la version pro de ACF"
		cd $pathtoinstall
		cd wp-content/plugins/
		curl -L -v 'http://connect.advancedcustomfields.com/index.php?p=pro&a=download&k='$acfkey > advanced-custom-fields-pro.zip
		wp plugin install advanced-custom-fields-pro.zip --activate
fi

# Download from le dossier client DEV

bot "-> Je copie le dossier Master client Dev vers $foldername"
cd $pathtoinstall/wp-content/themes/
cp -R "$themepath" /$themename

# Activate theme
bot "-> J'active le thème $foldername:"
wp theme activate $themename

# Misc cleanup
bot "-> Je supprime les posts, comments et terms"
wp site empty --yes

bot "-> Je supprime Hello dolly et les themes de bases"
wp plugin delete hello
wp theme delete twentyfifteen
wp theme delete twentyseventeen
wp theme delete twentysixteen
wp option update blogdescription ''

# Create standard pages
bot "-> Je crée les pages standards accueil et mentions légales"
wp post create --post_type=page --post_title='Accueil' --post_status=publish
wp post create --post_type=page --post_title='Mentions L&eacute;gales' --post_status=publish

# La page d'accueil est une page
# Et c'est la page qui se nomme accueil
bot "-> Configuration de la page accueil"
wp option update show_on_front 'page'
wp option update page_on_front $(wp post list --post_type=page --post_status=publish --posts_per_page=1 --pagename=Accueil --field=ID --format=ids)

# Permalinks to /%postname%/
bot "-> J'active la structure des permaliens /%postname%/ et génère le fichier .htaccess"
wp rewrite structure "/%postname%/" --hard
wp rewrite flush --hard

#Modifier le fichier htaccess
bot "-> J'ajoute des règles Apache dans le fichier htaccess"
cd $pathtoinstall
echo "
#Interdire le listage des repertoires
Options All -Indexes

#Interdire l'accès au fichier wp-config.php
<Files wp-config.php>
 	order allow,deny
	deny from all
</Files>

#Intedire l'accès au fichier htaccess lui même
<Files .htaccess>
	order allow,deny 
	deny from all 
</Files>

# Compression Gzip avec Apache 2.0
<IfModule mod_deflate.c>
    # Force compression for mangled headers.
    # http://developer.yahoo.com/blogs/ydn/posts/2010/12/pushing-beyond-gzipping
    <IfModule mod_setenvif.c>
        <IfModule mod_headers.c>
            SetEnvIfNoCase ^(Accept-EncodXng|X-cept-Encoding|X{15}|~{15}|-{15})$ ^((gzip|deflate)\s*,?\s*)+|[X~-]{4,13}$ HAVE_Accept-Encoding
            RequestHeader append Accept-Encoding \"gzip,deflate\" env=HAVE_Accept-Encoding
        </IfModule>
    </IfModule>

    # Compress all output labeled with one of the following MIME-types
    # (for Apache versions below 2.3.7, you don't need to enable `mod_filter`
    #  and can remove the `<IfModule mod_filter.c>` and `</IfModule>` lines
    #  as `AddOutputFilterByType` is still in the core directives).
    <IfModule mod_filter.c>
        AddOutputFilterByType DEFLATE application/atom+xml \
                                      application/javascript \
                                      application/json \
                                      application/rss+xml \
                                      application/vnd.ms-fontobject \
                                      application/x-font-ttf \
                                      application/x-web-app-manifest+json \
                                      application/xhtml+xml \
                                      application/xml \
                                      font/opentype \
                                      image/svg+xml \
                                      image/x-icon \
                                      text/css \
                                      text/html \
                                      text/plain \
                                      text/x-component \
                                      text/xml
    </IfModule>
</IfModule>

#Desactiver les ETag
<IfModule mod_headers.c>
    Header unset ETag
    FileETag None
</IfModule>

<IfModule mod_expires.c>
    ExpiresActive on
    ExpiresDefault                                      \"access plus 1 month\"
  # CSS
    ExpiresByType text/css                              \"access plus 1 year\"
  # Data interchange
    ExpiresByType application/json                      \"access plus 0 seconds\"
    ExpiresByType application/xml                       \"access plus 0 seconds\"
    ExpiresByType text/xml                              \"access plus 0 seconds\"
  # Favicon (cannot be renamed!)
    ExpiresByType image/x-icon                          \"access plus 1 week\"
  # HTML components (HTCs)
    ExpiresByType text/x-component                      \"access plus 1 month\"
  # HTML
    ExpiresByType text/html                             \"access plus 0 seconds\"
  # JavaScript
    ExpiresByType application/javascript                \"access plus 1 year\"
  # Manifest files
    ExpiresByType application/x-web-app-manifest+json   \"access plus 0 seconds\"
    ExpiresByType text/cache-manifest                   \"access plus 0 seconds\"
  # Media
    ExpiresByType audio/ogg                             \"access plus 1 month\"
    ExpiresByType image/gif                             \"access plus 1 month\"
    ExpiresByType image/jpeg                            \"access plus 1 month\"
    ExpiresByType image/png                             \"access plus 1 month\"
    ExpiresByType video/mp4                             \"access plus 1 month\"
    ExpiresByType video/ogg                             \"access plus 1 month\"
    ExpiresByType video/webm                            \"access plus 1 month\"
  # Flash
    ExpiresByType application/x-shockwave-flash 	\"access plus 1 month\"
  # Web feeds
    ExpiresByType application/atom+xml                  \"access plus 1 hour\"
    ExpiresByType application/rss+xml                   \"access plus 1 hour\"
  # Web fonts
    ExpiresByType application/font-woff                 \"access plus 1 month\"
    ExpiresByType application/vnd.ms-fontobject         \"access plus 1 month\"
    ExpiresByType application/x-font-ttf                \"access plus 1 month\"
    ExpiresByType font/opentype                         \"access plus 1 month\"
    ExpiresByType image/svg+xml                         \"access plus 1 month\"
</IfModule>

# block visitors referred from semalt.com 
RewriteCond %{HTTP_REFERER} semalt\.com [NC] 
RewriteRule .* - [F]
" >> .htaccess

# Créer la page du styleguide
#bot "-> Je crée la page pour le styleguide et l'associe au template qui va bien."
#wp post create --post_type=page --post_title='Styleguide' --post_status=publish --page_template='page-styleguide.php'


# Si on veut versionner le projet sur Bibucket
read -p "Versionner le projet sur Bitbucket (y/n) ? " yn
case "$yn" in
    y ) 
		# On se positione dans le dossier du thème
		cd $pathtoinstall
		cd wp-content/themes/
		cd $foldername

		# On supprime le dossier git présent
		rm -f -r .git
	
		# On récupère les infos nécessaire
		read -p "Login ? " login
		read -p "Password ? " pass
		read -p "Nom du dépôt ? " depot
		
		#Créer le dépôt sur Bitbucket
		curl --user $login:$pass https://api.bitbucket.org/1.0/repositories/ --data name=$depot --data is_private='true'
	    
	    # Init git et lien avec le dépôt
	    git init 
	    git remote add origin git@bitbucket.org:$login/$depot.git 

	    success "-> OK ! adresse du dépôt est : https://bitbucket.org/$login/$depot";;
    n ) 
		echo "Tans pis !";;
esac


# Finish !
success "L'installation est terminée !"
echo "--------------------------------------"
echo -e "Url			: $url"
echo -e "Path			: $pathtoinstall"
echo -e "Admin login	: $adminlogin"
echo -e "Admin pass		: $adminpass"
echo -e "Admin email	: $adminemail"
echo -e "DB name 		: $dbname"
echo -e "DB user 		: $dbuser"
echo -e "DB pass 		: $dbpass"
echo -e "DB prefix 		: $prefix"
echo -e "WP_DEBUG 		: TRUE"
echo "--------------------------------------"

cd $pathtoinstall

# Menu stuff
# echo -e "Je crée le menu principal, assigne les pages, et je lie l'emplacement du thème : "
# wp menu create "Menu Principal"
# wp menu item add-post menu-principal 3
# wp menu item add-post menu-principal 4
# wp menu item add-post menu-principal 5
# wp menu location assign menu-principal main-menu

# Git project
# REQUIRED : download Git at http://git-scm.com/downloads
 #echo -e "Je Git le projet :"
 #cd ../..
 #git init    # git project
 #git add -A  # Add all untracked files
 #git commit -m "Initial commit"   # Commit changes
