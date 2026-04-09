from django.core.exceptions import ValidationError


def validate_positive(value):
    if value < 0:
        raise ValidationError(f"{value} must be a non-negative number.")


def validate_positive_nonzero(value):
    if value <= 0:
        raise ValidationError(f"{value} must be a positive number greater than zero.")
