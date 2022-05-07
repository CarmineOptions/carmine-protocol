# Install into a Python3 virtual environment
install:
	virtualenv ~/cairo_venv
	. ~/cairo_venv/bin/activate && pip install cairo-lang cairo-nile
	#sudo apt install -y libgmp3-dev #on Linux,
	brew install gmp #on MacOS

# Build and test
build :
	. ~/cairo_venv/bin/activate && nile compile
test  :; pytest tests/
