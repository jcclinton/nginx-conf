server {
	listen   80;
	server_name  www.booksadvanced.com;
	return 301 $scheme://booksadvanced.com$request_uri;
}


server {

	listen   80;
	server_name booksadvanced.com;


#include document_root and error/access log paths
	include /etc/nginx/custom.conf.d/ba_paths;

	index  index.php index.html;

# Global restrictions
# move this to its own file
location = /favicon.ico {
	#expires max;
	log_not_found off;
	access_log off;
	break;
}

location = /robots.txt {
	allow all;
	log_not_found off;
	access_log off;
	break;
}

# Deny all attempts to access hidden files such as .htaccess, .htpasswd, .DS_Store (Mac).
location ~ /\. {
	deny all;
	access_log off;
	log_not_found off;
}

## Static files are served directly
	location ~* \.(?:js|css|png|jpg|jpeg|gif)$ {
		#expires 30d;
		#add_header Pragma public;
		#add_header Cache-Control "public, must-revalidate, proxy-revalidate";
		access_log off;
		#log_not_found off;
		break;
	}


	location /sitemap.xml.gz {
		add_header Cache-Control "public, must-revalidate";
		break;
	}

	location /sitemap.xml {
## when its time to turn on the redirect, remove these lines
		add_header Cache-Control "public, must-revalidate";
		break;
		#rewrite ^/(.*) $scheme://booksadvanced.com/sitemap.xml.gz permanent;
	}

	location / {
		#auth_basic "Restricted";
		#auth_basic_user_file htpasswd;

#goto considered harmful, unless the servers a teapot
		error_page 418 = @site;
		recursive_error_pages on;

#	bypass the cache for known users
	if ($http_cookie ~* "comment_author_|wordpress|wp-postpass_" ) {
		return 418;
	}

#	bypass the cache for post requests
	if ($request_method = POST) {
		return 418;
	}

# Using pretty permalinks, so bypass the cache for any query string
	if ($query_string) {
		return 418;
	}

# tries to find the files in sequence
#first tries supercache, then the exact uri, then the directory, finally passes it off to wordpress
		try_files /wp-content/cache/supercache/$host${request_uri}index.html $uri $uri/ @wordpress;
		#try_files $uri $uri/ @wordpress;
	}

	location @site {
		try_files $uri $uri/ @wordpress;
	}

	location @wordpress {
# adding q=$1 get param breaks supercaching
		#rewrite ^(.+)$ /index.php?q=$1 last;
		rewrite . /index.php last;
	}

# pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
#
	location ~ \.php$ {
		try_files $uri =404;
		fastcgi_split_path_info ^(.+\.php)(/.+)$;
		fastcgi_pass 127.0.0.1:9000;
		fastcgi_index index.php;
		include /etc/nginx/fastcgi_params;
		fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
	}
}

