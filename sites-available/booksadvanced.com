server {
	listen   80;
	server_name  www.booksadvanced.com;
	return 301 $scheme://booksadvanced.com$request_uri;
}

server {
	listen 80;
	server_name staging.booksadvanced.com;

	include /etc/nginx/conf.d/staging_paths.conf;
	index  index.php index.html;
	include /etc/nginx/conf.d/restrictions.conf;
	include /etc/nginx/conf.d/static_files.conf;

		auth_basic "Restricted";
		auth_basic_user_file htpasswd;

	include /etc/nginx/conf.d/wordpress.conf;

}


server {

	listen   80;
	server_name booksadvanced.com;


#include document_root and error/access log paths
	include /etc/nginx/conf.d/ba_paths.conf;

	index  index.php index.html;

	include /etc/nginx/conf.d/restrictions.conf;
	include /etc/nginx/conf.d/static_files.conf;

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

	include /etc/nginx/conf.d/wordpress.conf;
}

