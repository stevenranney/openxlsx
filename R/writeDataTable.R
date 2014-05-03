#' @name writeDataTable
#' @title Write to a worksheet and format as a table
#' @author Alexander Walker
#' @param wb A Workbook object containing a worksheet.
#' @param sheet The worksheet to write to. Can be the worksheet index or name.
#' @param x A dataframe.
#' @param startCol A vector specifiying the starting columns(s) to write df
#' @param startRow A vector specifiying the starting row(s) to write df
#' @param xy An alternative to specifying startCol and startRow individually.  
#' A vector of the form c(startCol, startRow)
#' @param colNames If TRUE, column names of x are written.
#' @param rowNames If TRUE, row names of x are written.
#' @param tableStyle Any excel table style name.
#' @details columns of x with class Date, POSIXct of POSIXt are automatically
#' styled as dates.
#' @seealso \code{\link{addWorksheet}}
#' @seealso \code{\link{writeData}}
#' @export
#' @examples
#' ## see package vignette for further examples.
#' 
#' wb <- createWorkbook("Edgar Anderson")
#' 
#' addWorksheet(wb, "S1")
#' addWorksheet(wb, "S2")
#' addWorksheet(wb, "S3")
#' 
#' ## write data formatted as excel table with table filters
#' # default table style is "TableStyleMedium2"
#' writeDataTable(wb, "S1", x = iris)
#' 
#' writeDataTable(wb, "S2", x = mtcars, xy = c("B", 3), rowNames=TRUE, tableStyle="TableStyleLight9")
#' 
#' df <- data.frame("Date" = Sys.Date()-0:19, "T" = TRUE, "F" = FALSE, "Time" = Sys.time()-0:19*60*60,
#'                  "Cash" = paste("$",1:20), "Cash2" = 31:50,
#'                  "hLink" = "http://cran.r-project.org/", stringsAsFactors = FALSE)
#' 
#' class(df$Cash) <- "currency"
#' class(df$Cash2) <- "accounting"
#' class(df$hLink) <- "hyperlink"
#' 
#' writeDataTable(wb, "S3", x = df, startRow = 4, rowNames=TRUE, tableStyle="TableStyleMedium9")
#' 
#' saveWorkbook(wb, "writeDataTableExample.xlsx", overwrite = TRUE)
writeDataTable <- function(wb, sheet, x,
                           startCol = 1,
                           startRow = 1, 
                           xy = NULL,
                           colNames = TRUE,
                           rowNames = FALSE,
                           tableStyle = "TableStyleMedium2"){
  
  
  if(!is.null(xy)){
    if(length(xy) != 2)
      stop("xy parameter must have length 2")
    startCol = xy[[1]]
    startRow = xy[[2]]
  }
  
  
  ## Input validating
  if(!"Workbook" %in% class(wb)) stop("First argument must be a Workbook.")
  if(!"data.frame" %in% class(x)) stop("x must be a data.frame.")
  if(!is.logical(colNames)) stop("colNames must be a logical.")
  if(!is.logical(rowNames)) stop("rowNames must be a logical.")
  
  ## convert startRow and startCol
  startCol <- convertFromExcelRef(startCol)
  startRow <- as.numeric(startRow)
  
  ##Coordinates for each section
  if(rowNames)
    x <- cbind(data.frame("row names" = rownames(x)), x)
  
  ## If 0 rows append a blank row  
  
  validNames <- c(paste0("TableStyleLight", 1:21), paste0("TableStyleMedium", 1:28), paste0("TableStyleDark", 1:11))
  if(!tolower(tableStyle) %in% tolower(validNames)){
    stop("Invalid table style.")
  }else{
    tableStyle <- validNames[grepl(paste0("^", tableStyle, "$"), validNames, ignore.case = TRUE)]
  }
  
  tableStyle <- na.omit(tableStyle)
  if(length(tableStyle) == 0)
    stop("Unknown table style.")
  
  showColNames <- colNames
  
  if(colNames)
    colNames <- colnames(x)
  else
    colNames <- paste0("Column", 1:ncol(x))
  
  ## If zero rows append an empty row (prevent XML from corrupting)
  if(nrow(x) == 0){
    x <- rbind(x, matrix("", nrow = 1, ncol = ncol(x)))
    names(x) <- colNames
  }
  
  ref1 <- paste0(.Call('openxlsx_convert2ExcelRef', startCol, LETTERS, PACKAGE="openxlsx"), startRow)
  ref2 <- paste0(.Call('openxlsx_convert2ExcelRef', startCol+ncol(x)-1, LETTERS, PACKAGE="openxlsx"), startRow+nrow(x)-1 + showColNames)
  ref <- paste(ref1, ref2, sep = ":")
  
  ## column class
  colClasses <- lapply(x, class)
  
  ## Style Dates as DATE
  if(any(c("Date", "POSIXct", "POSIXt") %in% unlist(colClasses))){
    
    dInds <- which(sapply(colClasses, function(x) "Date" %in% x))    
    pInds <- which(sapply(colClasses, function(x) any(c("POSIXct", "POSIXt") %in% x)))
    
    addStyle(wb, sheet = sheet, style=createStyle(numFmt="Date"), 
             rows= 1:nrow(x) + startRow + showColNames - 1,
             cols = unlist(c(dInds, pInds) + startCol - 1), gridExpand = TRUE)
  }
  
  
  ## style currency as CURRENCY
  if("currency" %in% tolower(colClasses)){
    inds <- which(sapply(colClasses, function(x) "currency" %in% tolower(x)))
    addStyle(wb, sheet = sheet, style=createStyle(numFmt = "CURRENCY"), 
             rows= 1:nrow(x) + startRow + showColNames - 1,
             cols = inds + startCol - 1, gridExpand = TRUE)
  }
  
  ## style accounting as ACCOUNTING
  if("accounting" %in% tolower(colClasses)){
    inds <- which(sapply(colClasses, function(x) "accounting" %in% tolower(x)))
    addStyle(wb, sheet = sheet, style=createStyle(numFmt = "ACCOUNTING"), 
             rows= 1:nrow(x) + startRow + showColNames - 1,
             cols = inds + startCol - 1, gridExpand = TRUE)  
  }
  
  ## style hyperlinks
  if("hyperlink" %in% tolower(colClasses)){
    inds <- which(sapply(colClasses, function(x) "hyperlink" %in% tolower(x)))
    addStyle(wb, sheet = sheet, style=createStyle(fontColour = "#0000FF", textDecoration = "underline"), 
             rows= 1:nrow(x) + startRow + showColNames - 1,
             cols = inds + startCol - 1, gridExpand = TRUE)  
  }
  
    
  ## write data to sheetData
  wb$writeData(df = x,
               colNames = showColNames,
               sheet = sheet,
               startRow = startRow,
               startCol = startCol)
  
  ## replace invalid XML characters
  colNames <- gsub('&', "&amp;", colNames)
  colNames <- gsub('"', "&quot;", colNames)
  colNames <- gsub("'", "&apos;", colNames)
  colNames <- gsub('<', "&lt;", colNames)
  colNames <- gsub('>', "&gt;", colNames)
  
  ## create table.xml and assign an id to worksheet tables
  wb$buildTable(sheet, colNames, ref, showColNames, tableStyle)
  
}