import io
import os
import urllib.parse
from datetime import datetime
from tempfile import NamedTemporaryFile
from typing import IO

import boto3
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import numpy as np
from dateutil.parser import parse
from pydantic import BaseModel, RootModel, ValidationError
from ulid import ULID


def generate_presigned_url(data: IO, file_name: str) -> str:
    s3 = boto3.client("s3")
    bucket = os.environ["AWS_LAMBDA_NAME"]
    # randomly generate key prefix and append file name
    key = f"{ULID()}/{file_name}"
    s3.upload_fileobj(data, bucket, key)
    return s3.generate_presigned_url(
        ClientMethod="get_object", Params={"Bucket": bucket, "Key": key}
    )


WaterHistory = RootModel[list[datetime]]
Wetness = RootModel[dict[datetime, int]]


class PlantData(BaseModel):
    id: str
    info: str
    name: str
    location: str
    wetness: Wetness
    water_history: WaterHistory


PlantsData = RootModel[dict[str, PlantData]]


def analyze(params: dict, body: dict) -> dict:
    try:
        start_date = datetime.strptime(params["start"], "%Y-%m-%d").date()
        end_date = datetime.strptime(params["end"], "%Y-%m-%d").date()
    except ValueError:
        return {"message": "Invalid date format"}
    except KeyError:
        return {"message": "Missing start or end params"}

    try:
        plants_data = PlantsData.model_validate(body)
    except ValidationError:
        return {"message": "Invalid body"}

    try:
        plant_id = params["id"]
    except KeyError:
        return {"message": "Missing id param"}
    try:
        plant_data = plants_data.root[plant_id]
    except KeyError:
        return {"message": "ID not found in body"}

    # Re-filtering water history and wetness measurements with the correct start and end dates
    filtered_water_history = [
        water_datetime
        for water_datetime in plant_data.water_history.root
        if start_date <= water_datetime.date() <= end_date
    ]
    ordered_water_history = sorted(filtered_water_history)
    filtered_wetness = {
        measurement_datetime: measurement
        for measurement_datetime, measurement in plant_data.wetness.root.items()
        if start_date <= measurement_datetime.date() <= end_date
    }
    ordered_wetness = {
        measurement_datetime: measurement
        for measurement_datetime, measurement in sorted(
            filtered_wetness.items(), key=lambda item: item[0]
        )
    }

    # Proceeding with the plot
    fig, ax = plt.subplots(figsize=(12, 6))

    # Plotting wetness measurements
    dates_wetness = list(ordered_wetness.keys())
    values_wetness = list(ordered_wetness.values())
    ax.plot(
        dates_wetness, values_wetness, label="Wetness Level", marker="o", color="blue"
    )

    # Plotting water history
    for i, date in enumerate(ordered_water_history):
        ax.axvline(x=date, color="green", linestyle="--", lw=1)
        if i > 0:
            days_since_last_watering = (date - ordered_water_history[i - 1]).days
            ax.text(
                date, 21, f"{days_since_last_watering} days", rotation=45, ha="right"
            )

    # Setting up the chart
    ax.set_title(
        f"Water and Wetness History for {plant_data.name.title()} ({plant_data.location.title()})"
    )
    ax.set_xlabel("Date")
    ax.set_ylabel("Wetness Level (0-20)")
    ax.legend()
    ax.set_ylim(0, 25)
    ax.xaxis.set_major_locator(mdates.MonthLocator())
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %Y"))
    ax.xaxis.set_minor_locator(mdates.DayLocator())
    plt.xticks(rotation=45)
    plt.grid(True)

    with NamedTemporaryFile() as tmpfile:
        fig.savefig(tmpfile, format="png")
        file_io = open(tmpfile.name, "rb")
        url_encoded_name = urllib.parse.quote(plant_data.name)
        file_name = f"{url_encoded_name}_{start_date.strftime('%Y-%m-%d')}_{end_date.strftime('%Y-%m-%d')}.png"
        presigned_url = generate_presigned_url(file_io, file_name)

    return {"message": "Analyzed", "url": presigned_url}
