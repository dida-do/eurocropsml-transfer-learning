from eurocropsmeta.placeholder import placeholder_func


def test_placeholder_func() -> None:
    assert placeholder_func(0) == 1
