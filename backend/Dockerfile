# 1. Imagen base ligera y optimizada
FROM python:3.12-slim

# 2. Crear directorio de la app
WORKDIR /app

# 3. Copiar requisitos primero para aprovechar la cache de Docker
COPY requirements.txt .

# 4. Instalar dependencias del backend
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copiar el código de la aplicación
COPY . .

# 6. Variables de entorno (puedes personalizarlas)
ENV PORT=8000
ENV DATABASE_URL="postgresql://pokedx_user:supersecret@db:5432/pokedx"

# 7. Exponer puerto interno del backend
EXPOSE 8000

# 8. Comando para correr la aplicación
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
