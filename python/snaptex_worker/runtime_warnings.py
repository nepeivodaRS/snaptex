import warnings


def configure_warning_filters():
    warnings.filterwarnings(
        "ignore",
        message="No ccache found\\. Please be aware that recompiling all source files may be required.*",
        category=UserWarning,
    )
    warnings.filterwarnings(
        "ignore",
        message="The image_processor_class argument is deprecated.*",
        category=FutureWarning,
    )
    warnings.filterwarnings(
        "ignore",
        message="`do_sample` is set to `False`.*",
        category=UserWarning,
    )
    warnings.filterwarnings(
        "ignore",
        message="A new version of Albumentations is available.*",
        category=UserWarning,
    )
