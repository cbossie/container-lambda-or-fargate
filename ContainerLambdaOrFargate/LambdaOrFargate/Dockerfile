FROM mcr.microsoft.com/dotnet/runtime:6.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["LambdaOrFargate/LambdaOrFargate.csproj", "LambdaOrFargate/"]
RUN dotnet restore "LambdaOrFargate/LambdaOrFargate.csproj"
COPY . .
WORKDIR "/src/LambdaOrFargate"
RUN dotnet build "LambdaOrFargate.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "LambdaOrFargate.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "LambdaOrFargate.dll"]