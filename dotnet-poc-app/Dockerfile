FROM mcr.microsoft.com/dotnet/sdk:6.0-bullseye-slim AS build
# Set up GreenDot root certificate authority + Add GreeDot JFrog artifactory (on VPN, MitM cert signed by GreenDot Root CA) as a NuGet source
RUN echo "-----BEGIN CERTIFICATE-----\nMIIFBzCCAu+gAwIBAgIQYM42qZmOTqpERS5Av4xsqDANBgkqhkiG9w0BAQsFADAW\nMRQwEgYDVQQDEwtnZGNyb290Y2EwMTAeFw0xMjA4MDIwMDEzMDFaFw00MjA4MDIw\nMDIyNTlaMBYxFDASBgNVBAMTC2dkY3Jvb3RjYTAxMIICIjANBgkqhkiG9w0BAQEF\nAAOCAg8AMIICCgKCAgEAuMmHKVrGU5ewETikhzpGg02gG16TDycj/zcpKrT7fgXa\nYizynTcSOoloqr0lghcG7bBZ9z95EZhlPZVpA0jMeq4Kfp1gJf6+fozpUxnxzQh3\noTHnoRpDPqwS4hLs92iVGtcQdIba/vbPpvkwWcaP2JacabqKF13jINTet4p/yKWL\n+tuiXb6JSBJ9MMrdxJJt8lMx74R4uM4+qru2r/uvGKaqjBep2IhNSfAp+J+69DCb\nIxHO4oxVpdNTP1KhfSH1a+73WB7bMsyiU/KOP025lH75dkTqnvCG9n/4WJNgMPlN\nmYX0FT4I7oJfG4ih8TGnq7i6l1aqBKmrvGMPmzcbYrE8dqXtWDis23/pdP+KVbB4\nXN346euQmGRFBLic66GqhAGOWUw2BmflqHfOh4E7r8webWIXSc90L53t/btQ7U2S\nSU4nLUxK+7D9JubEz6Ga6PT9A+1ut+SL1pld21v52MxKT6GbFrrzv7gmc2Z2Hsdc\ntS51YxAX43USHd+LoUyX2bKXuCBfoz5rBSRHkj7J6qEeHBvSWXWPsMVnhsvydIxR\nKRRC42Gek8X0tN+GgxRab13PMN772RkbHoNtSeW0lAA+2/4FRwEE7q+ZhBLngexz\nDiZow7vo+e0dvYEnv0zzyNGzXbmrTaxChSG26AWgjDfyzMauhhbi4Qs9jN0Aw7EC\nAwEAAaNRME8wCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE\nFJYOCErJ6Nv1DaZGOeo/7+AteFQ1MBAGCSsGAQQBgjcVAQQDAgEAMA0GCSqGSIb3\nDQEBCwUAA4ICAQBGkCswR0N5SrsKPkxmuj1t62Dzs+9rI9HJgO2Kq+dK6VGW9cJq\nDjePmixp/bObwmXEddhsr1t+WKi3+TSO19OWBZBzY6Yfl+9WaCYwGytpjd71c3JQ\ngkb6njkQgfYh1e9QemN1uL3cSmIFXGT7VCtv46OdTmDd6BUPhq+M/LXIaDvYZR0n\nA8+5V14VgG+lGjgeAr7QKfs/LPR88jcKCoSfWxTFim6ZOcSkRepi6DLT6mRQT6r4\nK8rl/gEe0z5r9ZtcGo5TKCD6v6tcUQ/7+vVgkA8T9Rx1A0EAaNZZDOjZ4unUtXX0\nRzW8eY4wN48GM/9Bmwf5nE/uEL2N0CF6z+AuMgMHfhaxRNwqKieEMYAMbUPQYosM\nw00M8kdgRIaSmg2IkCOj+UKUtJ4fpgE7MJ+Jqi5S13dsyzvn1E3lypO28kJ6YCwN\nnANST2i5Xk8y5V0W850k9dkfdnRgxe44JyAe0Fe7WNTGheVoYDox/gE2VWVoy25f\nYoN7kjDKErFmJbynOEEDRgPrJKfaPJg1lVZCVy/8nTE/kizAOJBfh7bp6K0ldKUq\nSPIvDg9a6wtQFJMEHdhsXBSjNcwJ9HiVYBrBjyP02gGRjRptv02CXWrZcqwJJe6A\n1UVMDTvwOlvJTCWYKRNjTEmSzdHv3uLlT12I/dIBmqGVfHEYhAZnkc402g==\n-----END CERTIFICATE-----\n" >> /usr/local/share/ca-certificates/gdcrootca01.crt
RUN update-ca-certificates
ARG ARTIFACTORY_USERNAME
ARG ARTIFACTORY_PASSWORD
RUN dotnet nuget add source \
    https://re-artifactory.gdotkubenp.com/artifactory/api/nuget/v3/GD_Common \
    --name GD_Common \
    --username $ARTIFACTORY_USERNAME \
    --password $ARTIFACTORY_PASSWORD \
    --store-password-in-clear-text
# restore
WORKDIR /src
COPY src/appsettings.json appsettings.json
COPY src/appsettings.Development.json appsettings.Development.json
COPY src/NLog.config NLog.config
COPY src/MicroservicePOC.csproj MicroservicePOC.csproj
RUN dotnet restore
# build
COPY src/ src/
RUN dotnet build /src/MicroservicePOC.csproj -c Debug -o /src/output --no-restore
# Copy only finished output (do not include source in final Docker image layer)
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app
COPY --from=build /src/output .
EXPOSE 3000
ENTRYPOINT ["dotnet", "MicroservicePOC.dll"]