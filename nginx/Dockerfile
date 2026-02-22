# ---- Build customer app ----
FROM node:20-alpine AS build-customer
WORKDIR /app
COPY QrCafe-Web/qrcafe-web/package.json QrCafe-Web/qrcafe-web/package-lock.json ./
RUN npm install
COPY QrCafe-Web/qrcafe-web/ .
ENV NG_BUILD_FONTS_INLINE=false
RUN npx ng build --configuration=production

# ---- Build admin app ----
FROM node:20-alpine AS build-admin
WORKDIR /app
COPY QrCafe-Web-Admin/qrcafe-admin/package.json QrCafe-Web-Admin/qrcafe-admin/package-lock.json ./
RUN npm install
COPY QrCafe-Web-Admin/qrcafe-admin/ .
ENV NG_BUILD_FONTS_INLINE=false
RUN npx ng build --configuration=production --base-href=/admin/

# ---- Nginx runtime ----
FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=build-customer /app/dist/qrcafe-web/browser /usr/share/nginx/html/customer
COPY --from=build-admin    /app/dist/qrcafe-admin/browser /usr/share/nginx/html/admin

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
