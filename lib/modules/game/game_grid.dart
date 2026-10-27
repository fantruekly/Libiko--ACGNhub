const int gameGridColumns = 4;
const double gameGridSpacing = 16;
const double gameGridTitleExtent = 46;

int gameGridColumnsFor(double maxWidth) =>
    ((maxWidth - 32 + gameGridSpacing) / (180 + gameGridSpacing))
        .floor()
        .clamp(1, 6);

double gameGridCellWidth(double maxWidth, {int columns = gameGridColumns}) =>
    (maxWidth - 32 - gameGridSpacing * (columns - 1)) / columns;

double gameGridCellExtent(double maxWidth,
        {int columns = gameGridColumns, double textScale = 1}) =>
    gameGridCellWidth(maxWidth, columns: columns) * 2 / 3 + 38 * textScale + 8;
