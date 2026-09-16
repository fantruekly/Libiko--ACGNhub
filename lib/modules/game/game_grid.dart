const int gameGridColumns = 4;
const double gameGridSpacing = 16;
const double gameGridTitleExtent = 44;

double gameGridCellWidth(double maxWidth) =>
    (maxWidth - 32 - gameGridSpacing * (gameGridColumns - 1)) / gameGridColumns;

double gameGridCellExtent(double maxWidth) =>
    gameGridCellWidth(maxWidth) * 2 / 3 + gameGridTitleExtent;
