
import requests 
from bs4 import BeautifulSoup
import csv
import boto3


def lambda_handler(event, context):

    try:
        weather_scraping()

        file_name = 'weathers.csv'
        bucket_name = 'lfe-temperature-colbun'
        
        s3 = boto3.client('s3')
        s3.upload_file(file_name, bucket_name, file_name)
        print(f'Archivo subido exitosamente a {bucket_name}/{file_name}')
    except Exception as e:
        print(f'Error al subir el archivo: {e}')
    
    return {
        'statusCode': 200,
        'body': f'Archivo subido exitosamente a {bucket_name}/{file_name}'
    }

def weather_scraping():

    # URL de la página que deseas scrapear
    url = 'https://www.accuweather.com/en/cl/colbun/54034/daily-weather-forecast/54034'

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
    }

    # Realizar la solicitud HTTP a la URL
    response = requests.get(url, headers=headers)

    file_name = "weathers.csv"

    # Comprobar que la solicitud fue exitosa
    if response.status_code == 200:
        # Obtener el contenido HTML de la página
        page_content = response.text
        
        # Parsear el HTML usando BeautifulSoup
        soup = BeautifulSoup(page_content, 'html.parser')
        
        parent_div = soup.find('div', class_='page-content content-module')
                
  
        if parent_div:
            daily_wrappers = parent_div.find_all('div', class_='daily-wrapper')
            
            # Iterar sobre los daily-wrapper divs para encontrar los que tienen clase 'info'
            for wrapper in daily_wrappers:
                info_div = wrapper.find('div', class_='info')
                if info_div:
                    date_div = info_div.find('h2', class_='date')
                    span_date = date_div.find('span', class_= 'module-header sub date')

                    temperture = info_div.find('div', class_='temp')
                    temperature_string = temperture.get_text()

                    with open(file_name, mode='a', newline='') as file:
                        # Crear un escritor CSV
                        writer = csv.writer(file)
                        writer.writerow([span_date.get_text(), temperature_string.replace("\n", "")])    

    else:
        print(f'Error al acceder a la página: {response.status_code}')


lambda_handler(1,1)