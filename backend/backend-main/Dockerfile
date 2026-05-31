# Usa la imagen oficial de Node.js (versión LTS recomendada, basada en Alpine para que sea más ligera)
FROM node:18-alpine

# Establece el directorio de trabajo dentro del contenedor
WORKDIR /usr/src/app

# Copia los archivos de dependencias (package.json y package-lock.json)
COPY package*.json ./

# Instala las dependencias del proyecto
RUN npm install

# Copia el resto del código de la aplicación
COPY . .

# Expone el puerto que utiliza tu API
EXPOSE 3000

# Comando para iniciar la aplicación
CMD [ "npm", "start" ]
